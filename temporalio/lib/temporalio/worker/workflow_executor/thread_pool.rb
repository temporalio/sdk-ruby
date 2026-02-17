# frozen_string_literal: true

require 'etc'
require 'temporalio/internal/bridge/api'
require 'temporalio/internal/proto_utils'
require 'temporalio/internal/worker/workflow_instance'
require 'temporalio/scoped_logger'
require 'temporalio/worker/thread_pool'
require 'temporalio/worker/workflow_executor'
require 'temporalio/workflow'
require 'temporalio/workflow/definition'
require 'timeout'

module Temporalio
  class Worker
    class WorkflowExecutor
      # Thread pool implementation of {WorkflowExecutor}.
      #
      # Users should use {default} unless they have specific needs to change the thread pool or max threads.
      class ThreadPool < WorkflowExecutor
        # @return [ThreadPool] Default executor that lazily constructs an instance with default values.
        def self.default
          @default ||= ThreadPool.new
        end

        # Create a thread pool executor. Most users may prefer {default}.
        #
        # @param max_threads [Integer] Maximum number of threads to use concurrently.
        # @param thread_pool [Worker::ThreadPool] Thread pool to use.
        def initialize(max_threads: [4, Etc.nprocessors].max, thread_pool: Temporalio::Worker::ThreadPool.default) # rubocop:disable Lint/MissingSuper
          @max_threads = max_threads
          @thread_pool = thread_pool
          @workers_mutex = Mutex.new
          @workers = []
          @workers_by_worker_state_and_run_id = {}
        end

        # @!visibility private
        def _validate_worker(workflow_worker, worker_state)
          # Do nothing
        end

        # @!visibility private
        def _activate(activation, worker_state, &)
          # Get applicable worker
          worker = @workers_mutex.synchronize do
            run_key = [worker_state, activation.run_id]
            @workers_by_worker_state_and_run_id.fetch(run_key) do
              # If not found, get a new one either by creating if not enough or find the one with the fewest.
              new_worker = if @workers.size < @max_threads
                             created_worker = Worker.new(self)
                             @workers << created_worker
                             created_worker
                           else
                             @workers.min_by(&:workflow_count)
                           end
              @workers_by_worker_state_and_run_id[run_key] = new_worker
              new_worker.workflow_count += 1
              new_worker
            end
          end
          raise "No worker for run ID #{activation.run_id}" unless worker

          # Enqueue activation
          worker.enqueue_activation(activation, worker_state, &)
        end

        # @!visibility private
        def _thread_pool
          @thread_pool
        end

        # @!visibility private
        def _remove_workflow(worker_state, run_id)
          @workers_mutex.synchronize do
            worker = @workers_by_worker_state_and_run_id.delete([worker_state, run_id])
            if worker
              worker.workflow_count -= 1
              # Remove worker from array if done. The array should be small enough that the delete being O(N) is not
              # worth using a set or a map.
              if worker.workflow_count.zero?
                @workers.delete(worker)
                worker.shutdown
              end
            end
          end
        end

        # @!visibility private
        class Worker
          LOG_ACTIVATIONS = false

          attr_accessor :workflow_count

          def initialize(executor)
            @executor = executor
            @workflow_count = 0
            @queue = Queue.new
            executor._thread_pool.execute { run }
          end

          # @!visibility private
          def enqueue_activation(activation, worker_state, &completion_block)
            @queue << [:activate, activation, worker_state, completion_block]
          end

          # @!visibility private
          def shutdown
            @queue << [:shutdown]
          end

          private

          def run
            loop do
              work = @queue.pop
              if work.is_a?(Exception)
                Warning.warn("Failed activation: #{work}")
              elsif work.is_a?(Array)
                case work.first
                when :shutdown
                  return
                when :activate
                  activate(work[1], work[2], &work[3])
                end
              end
            rescue Exception => e # rubocop:disable Lint/RescueException
              Warning.warn("Unexpected failure during run: #{e.full_message}")
            end
          end

          def activate(activation, worker_state, &)
            worker_state.logger.debug("Received workflow activation: #{activation}") if LOG_ACTIVATIONS

            # Check whether it has eviction
            cache_remove_job = activation.jobs.find { |j| !j.remove_from_cache.nil? }&.remove_from_cache

            # If it's eviction only, just evict inline and do nothing else
            if cache_remove_job && activation.jobs.size == 1
              evict(worker_state, activation.run_id, cache_remove_job)
              worker_state.logger.debug('Sending empty workflow completion') if LOG_ACTIVATIONS
              yield Internal::Bridge::Api::WorkflowCompletion::WorkflowActivationCompletion.new(
                run_id: activation.run_id,
                successful: Internal::Bridge::Api::WorkflowCompletion::Success.new
              )
              return
            end

            completion = Timeout.timeout(
              worker_state.deadlock_timeout,
              DeadlockError,
              # TODO(cretz): Document that this affects all running workflows on this worker
              # and maybe test to see how that is mitigated
              "[TMPRL1101] Potential deadlock detected: workflow didn't yield " \
              "within #{worker_state.deadlock_timeout} second(s)."
            ) do
              # Get or create workflow
              instance = worker_state.get_or_create_running_workflow(activation.run_id) do
                create_instance(activation, worker_state)
              end

              # Activate. We expect most errors in here to have been captured inside.
              instance.activate(activation)
            rescue Exception => e # rubocop:disable Lint/RescueException
              worker_state.logger.error("Failed activation on workflow run ID: #{activation.run_id}")
              worker_state.logger.error(e)
              Internal::Worker::WorkflowInstance.new_completion_with_failure(
                run_id: activation.run_id,
                error: e,
                failure_converter: worker_state.data_converter.failure_converter,
                payload_converter: worker_state.data_converter.payload_converter
              )
            end

            # Go ahead and evict if there is an eviction job
            evict(worker_state, activation.run_id, cache_remove_job) if cache_remove_job

            # Complete the activation
            worker_state.logger.debug("Sending workflow completion: #{completion}") if LOG_ACTIVATIONS
            yield completion
          end

          def create_instance(initial_activation, worker_state)
            # Extract start job
            init_job = initial_activation.jobs.find { |j| !j.initialize_workflow.nil? }&.initialize_workflow
            raise 'Missing initialize job in initial activation' unless init_job

            # Obtain definition
            definition = worker_state.workflow_definitions[init_job.workflow_type]
            # If not present and not reserved, try dynamic
            if !definition && !Internal::ProtoUtils.reserved_name?(init_job.workflow_type)
              definition = worker_state.workflow_definitions[nil]
            end

            unless definition
              raise Error::ApplicationError.new(
                "Workflow type #{init_job.workflow_type} is not registered on this worker, available workflows: " +
                  worker_state.workflow_definitions.keys.compact.sort.join(', '),
                type: 'NotFoundError'
              )
            end

            Internal::Worker::WorkflowInstance.new(
              Internal::Worker::WorkflowInstance::Details.new(
                namespace: worker_state.namespace,
                task_queue: worker_state.task_queue,
                definition:,
                initial_activation:,
                logger: worker_state.logger,
                metric_meter: worker_state.metric_meter,
                payload_converter: worker_state.data_converter.payload_converter,
                failure_converter: worker_state.data_converter.failure_converter,
                interceptors: worker_state.workflow_interceptors,
                disable_eager_activity_execution: worker_state.disable_eager_activity_execution,
                illegal_calls: worker_state.illegal_calls,
                workflow_failure_exception_types: worker_state.workflow_failure_exception_types,
                unsafe_workflow_io_enabled: worker_state.unsafe_workflow_io_enabled,
                assert_valid_local_activity: worker_state.assert_valid_local_activity
              )
            )
          end

          def evict(worker_state, run_id, cache_remove_job)
            worker_state.evict_running_workflow(run_id, cache_remove_job)
            @executor._remove_workflow(worker_state, run_id)
          end
        end

        private_constant :Worker

        # Error raised when a processing a workflow task takes more than the expected amount of time.
        class DeadlockError < Exception; end # rubocop:disable Lint/InheritException
      end
    end
  end
end
