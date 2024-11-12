# frozen_string_literal: true

require 'temporalio/activity'
require 'temporalio/activity/definition'
require 'temporalio/cancellation'
require 'temporalio/internal/bridge/api'
require 'temporalio/internal/proto_utils'
require 'temporalio/scoped_logger'
require 'temporalio/worker/interceptor'

module Temporalio
  module Internal
    module Worker
      class ActivityWorker
        LOG_TASKS = false

        attr_reader :worker, :bridge_worker

        def initialize(worker, bridge_worker)
          @worker = worker
          @bridge_worker = bridge_worker
          @runtime_metric_meter = worker.options.client.connection.options.runtime.metric_meter

          # Create shared logger that gives scoped activity details
          @scoped_logger = ScopedLogger.new(@worker.options.logger)
          @scoped_logger.scoped_values_getter = proc {
            Activity::Context.current_or_nil&._scoped_logger_info
          }

          # Build up activity hash by name, failing if any fail validation
          @activities = worker.options.activities.each_with_object({}) do |act, hash|
            # Class means create each time, instance means just call, definition
            # does nothing special
            defn = Activity::Definition.from_activity(act)
            # Confirm name not in use
            raise ArgumentError, "Multiple activities named #{defn.name}" if hash.key?(defn.name)

            # Confirm executor is a known executor and let it initialize
            executor = worker.options.activity_executors[defn.executor]
            raise ArgumentError, "Unknown executor '#{defn.executor}'" if executor.nil?

            executor.initialize_activity(defn)

            hash[defn.name] = defn
          end

          # Need mutex for the rest of these
          @running_activities_mutex = Mutex.new
          @running_activities = {}
          @running_activities_empty_condvar = ConditionVariable.new
        end

        def set_running_activity(task_token, activity)
          @running_activities_mutex.synchronize do
            @running_activities[task_token] = activity
          end
        end

        def get_running_activity(task_token)
          @running_activities_mutex.synchronize do
            @running_activities[task_token]
          end
        end

        def remove_running_activity(task_token)
          @running_activities_mutex.synchronize do
            @running_activities.delete(task_token)
            @running_activities_empty_condvar.broadcast if @running_activities.empty?
          end
        end

        def wait_all_complete
          @running_activities_mutex.synchronize do
            @running_activities_empty_condvar.wait(@running_activities_mutex) until @running_activities.empty?
          end
        end

        def handle_task(task)
          @scoped_logger.debug("Received activity task: #{task}") if LOG_TASKS
          if !task.start.nil?
            handle_start_task(task.task_token, task.start)
          elsif !task.cancel.nil?
            handle_cancel_task(task.task_token, task.cancel)
          else
            raise "Unrecognized activity task: #{task}"
          end
        end

        def handle_start_task(task_token, start)
          set_running_activity(task_token, nil)

          # Find activity definition
          defn = @activities[start.activity_type]
          if defn.nil?
            raise Error::ApplicationError.new(
              "Activity #{start.activity_type} for workflow #{start.workflow_execution.workflow_id} " \
              "is not registered on this worker, available activities: #{@activities.keys.sort.join(', ')}",
              type: 'NotFoundError'
            )
          end

          # Run everything else in the excecutor
          executor = @worker.options.activity_executors[defn.executor]
          executor.execute_activity(defn) do
            # Set current executor
            Activity::Context._current_executor = executor
            # Execute with error handling
            execute_activity(task_token, defn, start)
          ensure
            # Unset at the end
            Activity::Context._current_executor = nil
          end
        rescue Exception => e # rubocop:disable Lint/RescueException We are intending to catch everything here
          remove_running_activity(task_token)
          @scoped_logger.warn("Failed starting activity #{start.activity_type}")
          @scoped_logger.warn(e)

          # We need to complete the activity task as failed, but this is on the
          # hot path for polling, so we want to complete it in the background
          begin
            @bridge_worker.complete_activity_task_in_background(
              Bridge::Api::CoreInterface::ActivityTaskCompletion.new(
                task_token:,
                result: Bridge::Api::ActivityResult::ActivityExecutionResult.new(
                  failed: Bridge::Api::ActivityResult::Failure.new(
                    # TODO(cretz): If failure conversion does slow failure
                    # encoding, it can gum up the system
                    failure: @worker.options.client.data_converter.to_failure(e)
                  )
                )
              )
            )
          rescue StandardError => e_inner
            @scoped_logger.error("Failed building start failure to return for #{start.activity_type}")
            @scoped_logger.error(e_inner)
          end
        end

        def handle_cancel_task(task_token, cancel)
          activity = get_running_activity(task_token)
          if activity.nil?
            @scoped_logger.warn("Cannot find activity to cancel for token #{task_token}")
            return
          end
          activity._server_requested_cancel = true
          _, cancel_proc = activity.cancellation
          begin
            cancel_proc.call(reason: cancel.reason.to_s)
          rescue StandardError => e
            @scoped_logger.warn("Failed cancelling activity #{activity.info.activity_type} \
              with ID #{activity.info.activity_id}")
            @scoped_logger.warn(e)
          end
        end

        def execute_activity(task_token, defn, start)
          # Build info
          info = Activity::Info.new(
            activity_id: start.activity_id,
            activity_type: start.activity_type,
            attempt: start.attempt,
            current_attempt_scheduled_time: Internal::ProtoUtils.timestamp_to_time(
              start.current_attempt_scheduled_time
            ) || raise, # Never nil
            heartbeat_details: ProtoUtils.convert_from_payload_array(
              @worker.options.client.data_converter,
              start.heartbeat_details.to_ary
            ),
            heartbeat_timeout: Internal::ProtoUtils.duration_to_seconds(start.heartbeat_timeout),
            local?: start.is_local,
            schedule_to_close_timeout: Internal::ProtoUtils.duration_to_seconds(start.schedule_to_close_timeout),
            scheduled_time: Internal::ProtoUtils.timestamp_to_time(start.scheduled_time) || raise, # Never nil
            start_to_close_timeout: Internal::ProtoUtils.duration_to_seconds(start.start_to_close_timeout),
            started_time: Internal::ProtoUtils.timestamp_to_time(start.started_time) || raise, # Never nil
            task_queue: @worker.options.task_queue,
            task_token:,
            workflow_id: start.workflow_execution.workflow_id,
            workflow_namespace: start.workflow_namespace,
            workflow_run_id: start.workflow_execution.run_id,
            workflow_type: start.workflow_type
          ).freeze

          # Build input
          input = Temporalio::Worker::Interceptor::ExecuteActivityInput.new(
            proc: defn.proc,
            args: ProtoUtils.convert_from_payload_array(
              @worker.options.client.data_converter,
              start.input.to_ary
            ),
            headers: ProtoUtils.headers_from_proto_map(start.header_fields, @worker.options.client.data_converter) || {}
          )

          # Run
          activity = RunningActivity.new(
            info:,
            cancellation: Cancellation.new,
            worker_shutdown_cancellation: @worker._worker_shutdown_cancellation,
            payload_converter: @worker.options.client.data_converter.payload_converter,
            logger: @scoped_logger,
            runtime_metric_meter: @runtime_metric_meter
          )
          Activity::Context._current_executor&.set_activity_context(defn, activity)
          set_running_activity(task_token, activity)
          run_activity(activity, input)
        rescue Exception => e # rubocop:disable Lint/RescueException We are intending to catch everything here
          @scoped_logger.warn("Failed starting or sending completion for activity #{start.activity_type}")
          @scoped_logger.warn(e)
          # This means that the activity couldn't start or send completion (run
          # handles its own errors).
          begin
            @bridge_worker.complete_activity_task(
              Bridge::Api::CoreInterface::ActivityTaskCompletion.new(
                task_token:,
                result: Bridge::Api::ActivityResult::ActivityExecutionResult.new(
                  failed: Bridge::Api::ActivityResult::Failure.new(
                    failure: @worker.options.client.data_converter.to_failure(e)
                  )
                )
              )
            )
          rescue StandardError => e_inner
            @scoped_logger.error("Failed sending failure for activity #{start.activity_type}")
            @scoped_logger.error(e_inner)
          end
        ensure
          Activity::Context._current_executor&.set_activity_context(defn, nil)
          remove_running_activity(task_token)
        end

        def run_activity(activity, input)
          result = begin
            # Build impl with interceptors
            # @type var impl: Temporalio::Worker::Interceptor::ActivityInbound
            impl = InboundImplementation.new(self)
            impl = @worker._all_interceptors.reverse_each.reduce(impl) do |acc, int|
              int.intercept_activity(acc)
            end
            impl.init(OutboundImplementation.new(self))

            # Execute
            result = impl.execute(input)

            # Success
            Bridge::Api::ActivityResult::ActivityExecutionResult.new(
              completed: Bridge::Api::ActivityResult::Success.new(
                result: @worker.options.client.data_converter.to_payload(result)
              )
            )
          rescue Exception => e # rubocop:disable Lint/RescueException We are intending to catch everything here
            if e.is_a?(Activity::CompleteAsyncError)
              # Wanting to complete async
              @scoped_logger.debug('Completing activity asynchronously')
              Bridge::Api::ActivityResult::ActivityExecutionResult.new(
                will_complete_async: Bridge::Api::ActivityResult::WillCompleteAsync.new
              )
            elsif e.is_a?(Error::CanceledError) && activity._server_requested_cancel
              # Server requested cancel
              @scoped_logger.debug('Completing activity as canceled')
              Bridge::Api::ActivityResult::ActivityExecutionResult.new(
                cancelled: Bridge::Api::ActivityResult::Cancellation.new(
                  failure: @worker.options.client.data_converter.to_failure(e)
                )
              )
            else
              # General failure
              @scoped_logger.warn('Completing activity as failed')
              @scoped_logger.warn(e)
              Bridge::Api::ActivityResult::ActivityExecutionResult.new(
                failed: Bridge::Api::ActivityResult::Failure.new(
                  failure: @worker.options.client.data_converter.to_failure(e)
                )
              )
            end
          end

          @scoped_logger.debug("Sending activity completion: #{result}") if LOG_TASKS
          @bridge_worker.complete_activity_task(
            Bridge::Api::CoreInterface::ActivityTaskCompletion.new(
              task_token: activity.info.task_token,
              result:
            )
          )
        end

        class RunningActivity < Activity::Context
          attr_reader :info, :cancellation, :worker_shutdown_cancellation, :payload_converter, :logger
          attr_accessor :_outbound_impl, :_server_requested_cancel

          def initialize( # rubocop:disable Lint/MissingSuper
            info:,
            cancellation:,
            worker_shutdown_cancellation:,
            payload_converter:,
            logger:,
            runtime_metric_meter:
          )
            @info = info
            @cancellation = cancellation
            @worker_shutdown_cancellation = worker_shutdown_cancellation
            @payload_converter = payload_converter
            @logger = logger
            @runtime_metric_meter = runtime_metric_meter
            @_outbound_impl = nil
            @_server_requested_cancel = false
          end

          def heartbeat(*details)
            raise 'Implementation not set yet' if _outbound_impl.nil?

            _outbound_impl.heartbeat(Temporalio::Worker::Interceptor::HeartbeatActivityInput.new(details:))
          end

          def metric_meter
            @metric_meter ||= @runtime_metric_meter.with_additional_attributes(
              {
                namespace: info.workflow_namespace,
                task_queue: info.task_queue,
                activity_type: info.activity_type
              }
            )
          end
        end

        class InboundImplementation < Temporalio::Worker::Interceptor::ActivityInbound
          def initialize(worker)
            super(nil) # steep:ignore
            @worker = worker
          end

          def init(outbound)
            context = Activity::Context.current
            raise 'Unexpected context type' unless context.is_a?(RunningActivity)

            context._outbound_impl = outbound
          end

          def execute(input)
            input.proc.call(*input.args)
          end
        end

        class OutboundImplementation < Temporalio::Worker::Interceptor::ActivityOutbound
          def initialize(worker)
            super(nil) # steep:ignore
            @worker = worker
          end

          def heartbeat(input)
            @worker.bridge_worker.record_activity_heartbeat(
              Bridge::Api::CoreInterface::ActivityHeartbeat.new(
                task_token: Activity::Context.current.info.task_token,
                details: ProtoUtils.convert_to_payload_array(@worker.worker.options.client.data_converter,
                                                             input.details)
              ).to_proto
            )
          end
        end
      end
    end
  end
end
