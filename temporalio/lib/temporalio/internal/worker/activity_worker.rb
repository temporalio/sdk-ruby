# frozen_string_literal: true

require 'temporalio/activity'
require 'temporalio/activity/definition'
require 'temporalio/cancellation'
require 'temporalio/converters/raw_value'
require 'temporalio/internal/bridge/api'
require 'temporalio/internal/proto_utils'
require 'temporalio/scoped_logger'
require 'temporalio/worker/interceptor'

module Temporalio
  module Internal
    module Worker
      # Worker for handling activity tasks. Upon overarching worker shutdown, {wait_all_complete} should be used to wait
      # for the activities to complete.
      class ActivityWorker
        LOG_TASKS = false

        attr_reader :worker, :bridge_worker

        def initialize(worker:, bridge_worker:)
          @worker = worker
          @bridge_worker = bridge_worker
          @runtime_metric_meter = worker.options.client.connection.options.runtime.metric_meter

          # Create shared logger that gives scoped activity details
          @scoped_logger = ScopedLogger.new(@worker.options.logger)
          @scoped_logger.scoped_values_getter = proc {
            Activity::Context.current_or_nil&._scoped_logger_info
          }

          # Build up activity hash by name (can be nil for dynamic), failing if any fail validation
          @activities = worker.options.activities.each_with_object({}) do |act, hash|
            # Class means create each time, instance means just call, definition
            # does nothing special
            defn = Activity::Definition::Info.from_activity(act)
            # Confirm name not in use
            raise ArgumentError, 'Only one dynamic activity allowed' if !defn.name && hash.key?(defn.name)
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

          # Find activity definition, falling back to dynamic if not found and not reserved name
          defn = @activities[start.activity_type]
          defn = @activities[nil] if !defn && !Internal::ProtoUtils.reserved_name?(start.activity_type)

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
        rescue Exception => e # rubocop:disable Lint/RescueException -- We are intending to catch everything here
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
          begin
            activity._cancel(
              reason: cancel.reason.to_s,
              details: Activity::CancellationDetails.new(
                gone_from_server: cancel.details.is_not_found,
                cancel_requested: cancel.details.is_cancelled,
                timed_out: cancel.details.is_timed_out,
                worker_shutdown: cancel.details.is_worker_shutdown,
                paused: cancel.details.is_paused,
                reset: cancel.details.is_reset
              )
            )
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
              start.heartbeat_details.to_ary,
              hints: nil
            ),
            heartbeat_timeout: Internal::ProtoUtils.duration_to_seconds(start.heartbeat_timeout),
            local?: start.is_local,
            priority: Priority._from_proto(start.priority),
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
          input = Temporalio::Worker::Interceptor::Activity::ExecuteInput.new(
            proc: defn.proc,
            # If the activity wants raw_args, we only decode we don't convert
            args: if defn.raw_args
                    payloads = start.input.to_ary
                    codec = @worker.options.client.data_converter.payload_codec
                    payloads = codec.decode(payloads) if codec
                    payloads.map { |p| Temporalio::Converters::RawValue.new(p) }
                  else
                    ProtoUtils.convert_from_payload_array(
                      @worker.options.client.data_converter,
                      start.input.to_ary,
                      hints: defn.arg_hints
                    )
                  end,
            result_hint: defn.result_hint,
            headers: ProtoUtils.headers_from_proto_map(start.header_fields, @worker.options.client.data_converter) || {}
          )

          # Run
          activity = RunningActivity.new(
            worker: @worker,
            info:,
            cancellation: Cancellation.new,
            worker_shutdown_cancellation: @worker._worker_shutdown_cancellation,
            payload_converter: @worker.options.client.data_converter.payload_converter,
            logger: @scoped_logger,
            runtime_metric_meter: @runtime_metric_meter
          )
          Activity::Context._current_executor&.set_activity_context(defn, activity)
          set_running_activity(task_token, activity)
          run_activity(defn, activity, input)
        rescue Exception => e # rubocop:disable Lint/RescueException -- We are intending to catch everything here
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

        def run_activity(defn, activity, input)
          result = begin
            # Create the instance. We choose to do this before interceptors so that it is available in the interceptor.
            activity.instance = defn.instance.is_a?(Proc) ? defn.instance.call : defn.instance # steep:ignore

            # Build impl with interceptors
            # @type var impl: Temporalio::Worker::Interceptor::Activity::Inbound
            impl = InboundImplementation.new(self)
            impl = @worker._activity_interceptors.reverse_each.reduce(impl) do |acc, int|
              int.intercept_activity(acc)
            end
            impl.init(OutboundImplementation.new(self, activity.info.task_token))

            # Execute
            result = impl.execute(input)

            # Success
            Bridge::Api::ActivityResult::ActivityExecutionResult.new(
              completed: Bridge::Api::ActivityResult::Success.new(
                result: @worker.options.client.data_converter.to_payload(result, hint: input.result_hint)
              )
            )
          rescue Exception => e # rubocop:disable Lint/RescueException -- We are intending to catch everything here
            if e.is_a?(Activity::CompleteAsyncError)
              # Wanting to complete async
              @scoped_logger.debug('Completing activity asynchronously')
              Bridge::Api::ActivityResult::ActivityExecutionResult.new(
                will_complete_async: Bridge::Api::ActivityResult::WillCompleteAsync.new
              )
            elsif e.is_a?(Error::CanceledError) && activity.cancellation_details&.paused?
              # Server requested pause
              @scoped_logger.debug('Completing activity as failed due to exception caused by pause')
              Bridge::Api::ActivityResult::ActivityExecutionResult.new(
                failed: Bridge::Api::ActivityResult::Failure.new(
                  failure: @worker.options.client.data_converter.to_failure(
                    Error._with_backtrace_and_cause(
                      Error::ApplicationError.new('Activity paused', type: 'ActivityPause'), backtrace: nil, cause: e
                    )
                  )
                )
              )
            elsif e.is_a?(Error::CanceledError) && activity.cancellation_details&.reset?
              # Server requested reset
              @scoped_logger.debug('Completing activity as failed due to exception caused by reset')
              Bridge::Api::ActivityResult::ActivityExecutionResult.new(
                failed: Bridge::Api::ActivityResult::Failure.new(
                  failure: @worker.options.client.data_converter.to_failure(
                    Error._with_backtrace_and_cause(
                      Error::ApplicationError.new('Activity reset', type: 'ActivityReset'), backtrace: nil, cause: e
                    )
                  )
                )
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
              log_level = if e.is_a?(Error::ApplicationError) && e.category == Error::ApplicationError::Category::BENIGN
                            Logger::DEBUG
                          else
                            Logger::WARN
                          end
              @scoped_logger.add(log_level, 'Completing activity as failed')
              @scoped_logger.add(log_level, e)
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

        def assert_valid_activity(activity)
          defn = @activities[activity]
          defn = @activities[nil] if !defn && !Internal::ProtoUtils.reserved_name?(activity)

          return unless defn.nil?

          raise ArgumentError,
                "Activity #{activity} " \
                "is not registered on this worker, available activities: #{@activities.keys.sort.join(', ')}"
        end

        class RunningActivity < Activity::Context
          attr_reader :info, :cancellation, :cancellation_details, :worker_shutdown_cancellation,
                      :payload_converter, :logger, :_server_requested_cancel
          attr_accessor :instance, :_outbound_impl

          def initialize( # rubocop:disable Lint/MissingSuper
            worker:,
            info:,
            cancellation:,
            worker_shutdown_cancellation:,
            payload_converter:,
            logger:,
            runtime_metric_meter:
          )
            @worker = worker
            @info = info
            @cancellation = cancellation
            @cancellation_details = nil
            @worker_shutdown_cancellation = worker_shutdown_cancellation
            @payload_converter = payload_converter
            @logger = logger
            @runtime_metric_meter = runtime_metric_meter
            @_outbound_impl = nil
            @_server_requested_cancel = false
          end

          def heartbeat(*details, detail_hints: nil)
            raise 'Implementation not set yet' if _outbound_impl.nil?

            # No-op if local
            return if info.local?

            _outbound_impl.heartbeat(
              Temporalio::Worker::Interceptor::Activity::HeartbeatInput.new(details:, detail_hints:)
            )
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

          def client
            @worker.client
          end

          def _cancel(reason:, details:)
            # Do not issue cancel if already canceled
            return if @cancellation_details

            @_server_requested_cancel = true
            # Set the cancellation details _before_ issuing the cancel itself
            @cancellation_details = details
            _, cancel_proc = cancellation
            cancel_proc.call(reason:)
          end
        end

        class InboundImplementation < Temporalio::Worker::Interceptor::Activity::Inbound
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

        class OutboundImplementation < Temporalio::Worker::Interceptor::Activity::Outbound
          def initialize(worker, task_token)
            super(nil) # steep:ignore
            @worker = worker
            @task_token = task_token
          end

          def heartbeat(input)
            @worker.bridge_worker.record_activity_heartbeat(
              Bridge::Api::CoreInterface::ActivityHeartbeat.new(
                task_token: @task_token,
                details: ProtoUtils.convert_to_payload_array(@worker.worker.options.client.data_converter,
                                                             input.details,
                                                             hints: input.detail_hints)
              ).to_proto
            )
          end
        end
      end
    end
  end
end
