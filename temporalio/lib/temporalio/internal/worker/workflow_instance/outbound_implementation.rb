# frozen_string_literal: true

require 'temporalio/activity/definition'
require 'temporalio/cancellation'
require 'temporalio/error'
require 'temporalio/internal/bridge/api'
require 'temporalio/internal/proto_utils'
require 'temporalio/internal/worker/workflow_instance'
require 'temporalio/internal/worker/workflow_instance/nexus_operation_handle'
require 'temporalio/worker/interceptor'
require 'temporalio/workflow'
require 'temporalio/workflow/child_workflow_handle'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Root implementation of the outbound interceptor.
        class OutboundImplementation < Temporalio::Worker::Interceptor::Workflow::Outbound
          def initialize(instance)
            super(nil) # steep:ignore
            @instance = instance
            @activity_counter = 0
            @timer_counter = 0
            @child_counter = 0
            @nexus_operation_counter = 0
            @external_signal_counter = 0
            @external_cancel_counter = 0
          end

          def cancel_external_workflow(input)
            # Add command
            seq = (@external_cancel_counter += 1)
            cmd = Bridge::Api::WorkflowCommands::RequestCancelExternalWorkflowExecution.new(
              seq:,
              workflow_execution: Bridge::Api::Common::NamespacedWorkflowExecution.new(
                namespace: @instance.info.namespace,
                workflow_id: input.id,
                run_id: input.run_id
              )
            )
            @instance.add_command(
              Bridge::Api::WorkflowCommands::WorkflowCommand.new(request_cancel_external_workflow_execution: cmd)
            )
            @instance.pending_external_cancels[seq] = Fiber.current

            # Wait
            resolution = begin
              Fiber.yield
            ensure
              # Remove pending
              @instance.pending_external_cancels.delete(seq)
            end

            # Raise if resolution has failure
            return unless resolution.failure

            raise @instance.failure_converter.from_failure(resolution.failure, @instance.payload_converter)
          end

          def execute_activity(input)
            if input.schedule_to_close_timeout.nil? && input.start_to_close_timeout.nil?
              raise ArgumentError, 'Activity must have schedule_to_close_timeout or start_to_close_timeout'
            end

            execute_activity_with_local_backoffs(local: false, cancellation: input.cancellation,
                                                 result_hint: input.result_hint) do
              seq = (@activity_counter += 1)
              @instance.add_command(
                Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                  schedule_activity: Bridge::Api::WorkflowCommands::ScheduleActivity.new(
                    seq:,
                    activity_id: input.activity_id || seq.to_s,
                    activity_type: input.activity,
                    task_queue: input.task_queue,
                    headers: ProtoUtils.headers_to_proto_hash(input.headers, @instance.payload_converter),
                    arguments: ProtoUtils.convert_to_payload_array(
                      @instance.payload_converter, input.args, hints: input.arg_hints
                    ),
                    schedule_to_close_timeout: ProtoUtils.seconds_to_duration(input.schedule_to_close_timeout),
                    schedule_to_start_timeout: ProtoUtils.seconds_to_duration(input.schedule_to_start_timeout),
                    start_to_close_timeout: ProtoUtils.seconds_to_duration(input.start_to_close_timeout),
                    heartbeat_timeout: ProtoUtils.seconds_to_duration(input.heartbeat_timeout),
                    retry_policy: input.retry_policy&._to_proto,
                    cancellation_type: input.cancellation_type,
                    do_not_eagerly_execute: input.disable_eager_execution,
                    priority: input.priority._to_proto
                  ),
                  user_metadata: ProtoUtils.to_user_metadata(input.summary, nil, @instance.payload_converter)
                )
              )
              seq
            end
          end

          def execute_local_activity(input)
            if input.schedule_to_close_timeout.nil? && input.start_to_close_timeout.nil?
              raise ArgumentError, 'Activity must have schedule_to_close_timeout or start_to_close_timeout'
            end

            @instance.assert_valid_local_activity.call(input.activity)

            execute_activity_with_local_backoffs(local: true, cancellation: input.cancellation,
                                                 result_hint: input.result_hint) do |do_backoff|
              seq = (@activity_counter += 1)
              @instance.add_command(
                Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                  schedule_local_activity: Bridge::Api::WorkflowCommands::ScheduleLocalActivity.new(
                    seq:,
                    activity_id: input.activity_id || seq.to_s,
                    activity_type: input.activity,
                    headers: ProtoUtils.headers_to_proto_hash(input.headers, @instance.payload_converter),
                    arguments: ProtoUtils.convert_to_payload_array(
                      @instance.payload_converter, input.args, hints: input.arg_hints
                    ),
                    schedule_to_close_timeout: ProtoUtils.seconds_to_duration(input.schedule_to_close_timeout),
                    schedule_to_start_timeout: ProtoUtils.seconds_to_duration(input.schedule_to_start_timeout),
                    start_to_close_timeout: ProtoUtils.seconds_to_duration(input.start_to_close_timeout),
                    retry_policy: input.retry_policy&._to_proto,
                    cancellation_type: input.cancellation_type,
                    local_retry_threshold: ProtoUtils.seconds_to_duration(input.local_retry_threshold),
                    attempt: do_backoff&.attempt || 0,
                    original_schedule_time: do_backoff&.original_schedule_time
                  ),
                  user_metadata: ProtoUtils.to_user_metadata(input.summary, nil, @instance.payload_converter)
                )
              )
              seq
            end
          end

          def execute_activity_with_local_backoffs(local:, cancellation:, result_hint:, &block)
            # We do not even want to schedule if the cancellation is already cancelled. We choose to use canceled
            # failure instead of wrapping in activity failure which is similar to what other SDKs do, with the accepted
            # tradeoff that it makes rescue more difficult (hence the presence of Error.canceled? helper).
            raise Error::CanceledError, 'Activity canceled before scheduled' if cancellation.canceled?

            # This has to be done in a loop for local activity backoff
            last_local_backoff = nil
            loop do
              result = execute_activity_once(local:, cancellation:, last_local_backoff:, result_hint:, &block)
              return result unless result.is_a?(Bridge::Api::ActivityResult::DoBackoff)

              # @type var result: untyped
              last_local_backoff = result
              # Have to sleep the amount of the backoff, which can be canceled with the same cancellation
              # TODO(cretz): What should this cancellation raise?
              Workflow.sleep(ProtoUtils.duration_to_seconds(result.backoff_duration), cancellation:)
            end
          end

          # If this doesn't raise, it returns success | DoBackoff
          def execute_activity_once(local:, cancellation:, last_local_backoff:, result_hint:, &block)
            # Add to pending activities (removed by the resolver)
            seq = block.call(last_local_backoff)
            @instance.pending_activities[seq] = Fiber.current

            # Add cancellation hook
            cancel_callback_key = cancellation.add_cancel_callback do
              # Only if the activity is present still
              if @instance.pending_activities.include?(seq)
                if local
                  @instance.add_command(
                    Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                      request_cancel_local_activity: Bridge::Api::WorkflowCommands::RequestCancelLocalActivity.new(seq:)
                    )
                  )
                else
                  @instance.add_command(
                    Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                      request_cancel_activity: Bridge::Api::WorkflowCommands::RequestCancelActivity.new(seq:)
                    )
                  )
                end
              end
            end

            # Wait
            resolution = begin
              Fiber.yield
            ensure
              # Remove pending and cancel callback
              @instance.pending_activities.delete(seq)
              cancellation.remove_cancel_callback(cancel_callback_key)
            end

            case resolution.status
            when :completed
              @instance.payload_converter.from_payload(resolution.completed.result, hint: result_hint)
            when :failed
              raise @instance.failure_converter.from_failure(resolution.failed.failure, @instance.payload_converter)
            when :cancelled
              raise @instance.failure_converter.from_failure(resolution.cancelled.failure, @instance.payload_converter)
            when :backoff
              resolution.backoff
            else
              raise "Unrecognized resolution status: #{resolution.status}"
            end
          end

          def initialize_continue_as_new_error(input)
            # Do nothing
          end

          def signal_child_workflow(input)
            _signal_external_workflow(
              id: input.id,
              run_id: nil,
              child: true,
              signal: input.signal,
              args: input.args,
              cancellation: input.cancellation,
              arg_hints: input.arg_hints,
              headers: input.headers
            )
          end

          def signal_external_workflow(input)
            _signal_external_workflow(
              id: input.id,
              run_id: input.run_id,
              child: false,
              signal: input.signal,
              args: input.args,
              cancellation: input.cancellation,
              arg_hints: input.arg_hints,
              headers: input.headers
            )
          end

          def _signal_external_workflow(id:, run_id:, child:, signal:, args:, cancellation:, arg_hints:, headers:)
            raise Error::CanceledError, 'Signal canceled before scheduled' if cancellation.canceled?

            # Add command
            seq = (@external_signal_counter += 1)
            cmd = Bridge::Api::WorkflowCommands::SignalExternalWorkflowExecution.new(
              seq:,
              signal_name: signal,
              args: ProtoUtils.convert_to_payload_array(@instance.payload_converter, args, hints: arg_hints),
              headers: ProtoUtils.headers_to_proto_hash(headers, @instance.payload_converter)
            )
            if child
              cmd.child_workflow_id = id
            else
              cmd.workflow_execution = Bridge::Api::Common::NamespacedWorkflowExecution.new(
                namespace: @instance.info.namespace,
                workflow_id: id,
                run_id:
              )
            end
            @instance.add_command(
              Bridge::Api::WorkflowCommands::WorkflowCommand.new(signal_external_workflow_execution: cmd)
            )
            @instance.pending_external_signals[seq] = Fiber.current

            # Add a cancellation callback
            cancel_callback_key = cancellation.add_cancel_callback do
              # Add the command but do not raise, we will let resolution do that
              @instance.add_command(
                Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                  cancel_signal_workflow: Bridge::Api::WorkflowCommands::CancelSignalWorkflow.new(seq:)
                )
              )
            end

            # Wait
            resolution = begin
              Fiber.yield
            ensure
              # Remove pending and cancel callback
              @instance.pending_external_signals.delete(seq)
              cancellation.remove_cancel_callback(cancel_callback_key)
            end

            # Raise if resolution has failure
            return unless resolution.failure

            raise @instance.failure_converter.from_failure(resolution.failure, @instance.payload_converter)
          end

          def sleep(input)
            # If already cancelled, raise as such
            if input.cancellation.canceled?
              raise Error::CanceledError,
                    input.cancellation.canceled_reason || 'Timer canceled before started'
            end

            # Disallow negative durations
            raise ArgumentError, 'Sleep duration cannot be less than 0' if input.duration&.negative?

            # If the duration is infinite, just wait for cancellation
            if input.duration.nil?
              input.cancellation.wait
              raise Error::CanceledError, input.cancellation.canceled_reason || 'Timer canceled'
            end

            # If duration is zero, we make it one millisecond. It was decided a 0 duration still makes a timer to ensure
            # determinism if a timer's duration is altered from non-zero to zero or vice versa.
            duration = input.duration
            duration = 0.001 if duration.zero?

            # Add command
            seq = (@timer_counter += 1)
            @instance.add_command(
              Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                start_timer: Bridge::Api::WorkflowCommands::StartTimer.new(
                  seq:,
                  start_to_fire_timeout: ProtoUtils.seconds_to_duration(duration)
                ),
                user_metadata: ProtoUtils.to_user_metadata(input.summary, nil, @instance.payload_converter)
              )
            )
            @instance.pending_timers[seq] = Fiber.current

            # Add a cancellation callback
            cancel_callback_key = input.cancellation.add_cancel_callback do
              # Only if the timer is still present
              fiber = @instance.pending_timers.delete(seq)
              if fiber
                # Add the command for cancel then raise
                @instance.add_command(
                  Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                    cancel_timer: Bridge::Api::WorkflowCommands::CancelTimer.new(seq:)
                  )
                )
                if fiber.alive?
                  fiber.raise(Error::CanceledError.new(input.cancellation.canceled_reason || 'Timer canceled'))
                end
              end
            end

            # Wait
            begin
              Fiber.yield
            ensure
              # Remove pending
              @instance.pending_timers.delete(seq)
            end

            # Remove cancellation callback (only needed on success)
            input.cancellation.remove_cancel_callback(cancel_callback_key)
          end

          def start_child_workflow(input)
            raise Error::CanceledError, 'Child canceled before scheduled' if input.cancellation.canceled?

            # Add the command
            seq = (@child_counter += 1)
            @instance.add_command(
              Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                start_child_workflow_execution: Bridge::Api::WorkflowCommands::StartChildWorkflowExecution.new(
                  seq:,
                  namespace: @instance.info.namespace,
                  workflow_id: input.id,
                  workflow_type: input.workflow,
                  task_queue: input.task_queue,
                  input: ProtoUtils.convert_to_payload_array(@instance.payload_converter, input.args,
                                                             hints: input.arg_hints),
                  workflow_execution_timeout: ProtoUtils.seconds_to_duration(input.execution_timeout),
                  workflow_run_timeout: ProtoUtils.seconds_to_duration(input.run_timeout),
                  workflow_task_timeout: ProtoUtils.seconds_to_duration(input.task_timeout),
                  parent_close_policy: input.parent_close_policy,
                  workflow_id_reuse_policy: input.id_reuse_policy,
                  retry_policy: input.retry_policy&._to_proto,
                  cron_schedule: input.cron_schedule,
                  headers: ProtoUtils.headers_to_proto_hash(input.headers, @instance.payload_converter),
                  memo: ProtoUtils.memo_to_proto_hash(input.memo, @instance.payload_converter),
                  search_attributes: input.search_attributes&._to_proto_hash,
                  cancellation_type: input.cancellation_type,
                  priority: input.priority._to_proto
                ),
                user_metadata: ProtoUtils.to_user_metadata(
                  input.static_summary, input.static_details, @instance.payload_converter
                )
              )
            )

            # Set as pending start and register cancel callback
            @instance.pending_child_workflow_starts[seq] = Fiber.current
            cancel_callback_key = input.cancellation.add_cancel_callback do
              # Send cancel if in start or pending
              if @instance.pending_child_workflow_starts.include?(seq) ||
                 @instance.pending_child_workflows.include?(seq)
                @instance.add_command(
                  Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                    cancel_child_workflow_execution: Bridge::Api::WorkflowCommands::CancelChildWorkflowExecution.new(
                      child_workflow_seq: seq
                    )
                  )
                )
              end
            end

            # Wait for start
            resolution = begin
              Fiber.yield
            ensure
              # Remove pending
              @instance.pending_child_workflow_starts.delete(seq)
            end

            case resolution.status
            when :succeeded
              # Create handle, passing along the cancel callback key, and set it as pending
              handle = ChildWorkflowHandle.new(
                id: input.id,
                first_execution_run_id: resolution.succeeded.run_id,
                instance: @instance,
                cancellation: input.cancellation,
                cancel_callback_key:,
                result_hint: input.result_hint
              )
              @instance.pending_child_workflows[seq] = handle
              handle
            when :failed
              # Remove cancel callback and handle failure
              input.cancellation.remove_cancel_callback(cancel_callback_key)
              if resolution.failed.cause == :START_CHILD_WORKFLOW_EXECUTION_FAILED_CAUSE_WORKFLOW_ALREADY_EXISTS
                raise Error::WorkflowAlreadyStartedError.new(
                  workflow_id: resolution.failed.workflow_id,
                  workflow_type: resolution.failed.workflow_type,
                  run_id: nil
                )
              end
              raise "Unknown child start fail cause: #{resolution.failed.cause}"
            when :cancelled
              # Remove cancel callback and handle cancel
              input.cancellation.remove_cancel_callback(cancel_callback_key)
              raise @instance.failure_converter.from_failure(resolution.cancelled.failure, @instance.payload_converter)
            else
              raise "Unknown resolution status: #{resolution.status}"
            end
          end

          def start_nexus_operation(input)
            raise Error::CanceledError, 'Nexus operation canceled before scheduled' if input.cancellation.canceled?

            # Add the command
            seq = (@nexus_operation_counter += 1)
            @instance.add_command(
              Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                schedule_nexus_operation: Bridge::Api::WorkflowCommands::ScheduleNexusOperation.new(
                  seq:,
                  endpoint: input.endpoint,
                  service: input.service,
                  operation: input.operation,
                  input: @instance.payload_converter.to_payload(input.arg, hint: input.arg_hint),
                  schedule_to_close_timeout: ProtoUtils.seconds_to_duration(input.schedule_to_close_timeout),
                  nexus_header: input.headers,
                  cancellation_type: input.cancellation_type
                ),
                user_metadata: ProtoUtils.to_user_metadata(input.summary, nil, @instance.payload_converter)
              )
            )

            # Set as pending start
            @instance.pending_nexus_operation_starts[seq] = Fiber.current

            # Register cancel callback
            cancel_callback_key = input.cancellation.add_cancel_callback do
              # Send cancel if in start or pending
              if @instance.pending_nexus_operation_starts.include?(seq) ||
                 @instance.pending_nexus_operations.include?(seq)
                @instance.add_command(
                  Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                    request_cancel_nexus_operation: Bridge::Api::WorkflowCommands::RequestCancelNexusOperation.new(
                      seq:
                    )
                  )
                )
              end
            end

            # Wait for start resolution
            resolution = begin
              Fiber.yield
            ensure
              # Remove pending start
              @instance.pending_nexus_operation_starts.delete(seq)
            end

            # Handle start failure
            if resolution.failed
              input.cancellation.remove_cancel_callback(cancel_callback_key)
              raise @instance.failure_converter.from_failure(resolution.failed, @instance.payload_converter)
            end

            # Create handle and add to pending operations (result will come via resolve_nexus_operation)
            handle = NexusOperationHandle.new(
              operation_token: resolution.operation_token,
              instance: @instance,
              cancellation: input.cancellation,
              cancel_callback_key:,
              result_hint: input.result_hint
            )
            @instance.pending_nexus_operations[seq] = handle

            handle
          end
        end
      end
    end
  end
end
