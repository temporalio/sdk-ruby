# frozen_string_literal: true

require 'temporalio/api/payload_visitor'
require 'temporalio/error'
require 'temporalio/internal/worker/workflow_instance'
require 'temporalio/scoped_logger'
require 'temporalio/workflow'
require 'temporalio/workflow/definition'
require 'timeout'

module Temporalio
  module Internal
    module Worker
      # Worker for handling workflow activations. Most activation work is delegated to the workflow executor.
      class WorkflowWorker
        def self.workflow_definitions(workflows)
          workflows.each_with_object({}) do |workflow, hash|
            # Load definition
            defn = begin
              if workflow.is_a?(Workflow::Definition::Info)
                workflow
              else
                Workflow::Definition::Info.from_class(workflow)
              end
            rescue StandardError
              raise ArgumentError, "Failed loading workflow #{workflow}"
            end

            # Confirm name not in use
            raise ArgumentError, "Multiple workflows named #{defn.name || '<dynamic>'}" if hash.key?(defn.name)

            hash[defn.name] = defn
          end
        end

        def initialize(worker:, bridge_worker:, workflow_definitions:)
          @executor = worker.options.workflow_executor

          payload_codec = worker.options.client.data_converter.payload_codec
          @workflow_payload_codec_thread_pool = worker.options.workflow_payload_codec_thread_pool
          if !Fiber.current_scheduler && payload_codec && !@workflow_payload_codec_thread_pool
            raise ArgumentError, 'Must have workflow payload codec thread pool if providing codec and not using fibers'
          end

          # If there is a payload codec, we need to build encoding and decoding visitors
          if payload_codec
            @payload_encoding_visitor = Api::PayloadVisitor.new(skip_search_attributes: true) do |payload_or_payloads|
              apply_codec_on_payload_visit(payload_or_payloads) { |payloads| payload_codec.encode(payloads) }
            end
            @payload_decoding_visitor = Api::PayloadVisitor.new(skip_search_attributes: true) do |payload_or_payloads|
              apply_codec_on_payload_visit(payload_or_payloads) { |payloads| payload_codec.decode(payloads) }
            end
          end

          @state = State.new(
            workflow_definitions:,
            bridge_worker:,
            logger: worker.options.logger,
            metric_meter: worker.options.client.connection.options.runtime.metric_meter,
            data_converter: worker.options.client.data_converter,
            deadlock_timeout: worker.options.debug_mode ? nil : 2.0,
            # TODO(cretz): Make this more performant for the default set?
            illegal_calls: WorkflowInstance::IllegalCallTracer.frozen_validated_illegal_calls(
              worker.options.illegal_workflow_calls || {}
            ),
            namespace: worker.options.client.namespace,
            task_queue: worker.options.task_queue,
            disable_eager_activity_execution: worker.options.disable_eager_activity_execution,
            workflow_interceptors: worker._workflow_interceptors,
            workflow_failure_exception_types: worker.options.workflow_failure_exception_types.map do |t|
              unless t.is_a?(Class) && t < Exception
                raise ArgumentError, 'All failure types must classes inheriting Exception'
              end

              t
            end.freeze
          )

          # Validate worker
          @executor._validate_worker(worker, @state)
        end

        def handle_activation(runner:, activation:, decoded:)
          # Encode in background if not encoded but it needs to be
          if @payload_encoding_visitor && !decoded
            if Fiber.current_scheduler
              Fiber.schedule { decode_activation(runner, activation) }
            else
              @workflow_payload_codec_thread_pool.execute { decode_activation(runner, activation) }
            end
          else
            @executor._activate(activation, @state) do |activation_completion|
              runner.apply_workflow_activation_complete(workflow_worker: self, activation_completion:, encoded: false)
            end
          end
        rescue Exception => e # rubocop:disable Lint/RescueException
          # Should never happen, executors are expected to trap things
          @state.logger.error("Failed issuing activation on workflow run ID: #{activation.run_id}")
          @state.logger.error(e)
        end

        def handle_activation_complete(runner:, activation_completion:, encoded:, completion_complete_queue:)
          if @payload_encoding_visitor && !encoded
            if Fiber.current_scheduler
              Fiber.schedule { encode_activation_completion(runner, activation_completion) }
            else
              @workflow_payload_codec_thread_pool.execute do
                encode_activation_completion(runner, activation_completion)
              end
            end
          else
            @state.bridge_worker.async_complete_workflow_activation(
              activation_completion.run_id, activation_completion.to_proto, completion_complete_queue
            )
          end
        end

        def on_shutdown_complete
          @state.evict_all
        end

        private

        def decode_activation(runner, activation)
          @payload_decoding_visitor.run(activation)
          runner.apply_workflow_activation_decoded(workflow_worker: self, activation:)
        end

        def encode_activation_completion(runner, activation_completion)
          @payload_encoding_visitor.run(activation_completion)
          runner.apply_workflow_activation_complete(workflow_worker: self, activation_completion:, encoded: true)
        end

        def apply_codec_on_payload_visit(payload_or_payloads, &)
          case payload_or_payloads
          when Temporalio::Api::Common::V1::Payload
            new_payloads = yield [payload_or_payloads]
            payload_or_payloads.metadata = new_payloads.first.metadata
            payload_or_payloads.data = new_payloads.first.data
          when Enumerable
            payload_or_payloads.replace(yield payload_or_payloads) # steep:ignore
          else
            raise 'Unrecognized visitor type'
          end
        end

        class State
          attr_reader :workflow_definitions, :bridge_worker, :logger, :metric_meter, :data_converter, :deadlock_timeout,
                      :illegal_calls, :namespace, :task_queue, :disable_eager_activity_execution,
                      :workflow_interceptors, :workflow_failure_exception_types

          def initialize(
            workflow_definitions:, bridge_worker:, logger:, metric_meter:, data_converter:, deadlock_timeout:,
            illegal_calls:, namespace:, task_queue:, disable_eager_activity_execution:,
            workflow_interceptors:, workflow_failure_exception_types:
          )
            @workflow_definitions = workflow_definitions
            @bridge_worker = bridge_worker
            @logger = logger
            @metric_meter = metric_meter
            @data_converter = data_converter
            @deadlock_timeout = deadlock_timeout
            @illegal_calls = illegal_calls
            @namespace = namespace
            @task_queue = task_queue
            @disable_eager_activity_execution = disable_eager_activity_execution
            @workflow_interceptors = workflow_interceptors
            @workflow_failure_exception_types = workflow_failure_exception_types

            @running_workflows = {}
            @running_workflows_mutex = Mutex.new
          end

          # This can never be called at the same time for the same run ID on the same state object
          def get_or_create_running_workflow(run_id, &)
            instance = @running_workflows_mutex.synchronize { @running_workflows[run_id] }
            # If instance is not there, we create it out of lock then store it under lock
            unless instance
              instance = yield
              @running_workflows_mutex.synchronize { @running_workflows[run_id] = instance }
            end
            instance
          end

          def evict_running_workflow(run_id)
            @running_workflows_mutex.synchronize { @running_workflows.delete(run_id) }
          end

          def evict_all
            @running_workflows_mutex.synchronize { @running_workflows.clear }
          end
        end
      end
    end
  end
end
