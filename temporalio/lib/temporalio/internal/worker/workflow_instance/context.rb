# frozen_string_literal: true

require 'temporalio/cancellation'
require 'temporalio/error'
require 'temporalio/internal/bridge/api'
require 'temporalio/internal/proto_utils'
require 'temporalio/internal/worker/workflow_instance'
require 'temporalio/internal/worker/workflow_instance/external_workflow_handle'
require 'temporalio/worker/interceptor'
require 'temporalio/workflow'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Context for all workflow calls. All calls in the {Workflow} class should call a method on this class and then
        # this class can delegate the call as needed to other parts of the workflow instance system.
        class Context
          def initialize(instance)
            @instance = instance
          end

          def all_handlers_finished?
            @instance.in_progress_handlers.empty?
          end

          def cancellation
            @instance.cancellation
          end

          def continue_as_new_suggested
            @instance.continue_as_new_suggested
          end

          def current_details
            @instance.current_details || ''
          end

          def current_details=(details)
            raise 'Details must be a String' unless details.nil? || details.is_a?(String)

            @instance.current_details = (details || '')
          end

          def current_deployment_version
            @instance.current_deployment_version
          end

          def current_history_length
            @instance.current_history_length
          end

          def current_history_size
            @instance.current_history_size
          end

          def current_update_info
            Fiber[:__temporal_update_info]
          end

          def deprecate_patch(patch_id)
            @instance.patch(patch_id:, deprecated: true)
          end

          def durable_scheduler_disabled(&)
            prev = Fiber.current_scheduler
            # Imply illegal call tracing disabled
            illegal_call_tracing_disabled do
              Fiber.set_scheduler(nil)
              yield
            ensure
              Fiber.set_scheduler(prev)
            end
          end

          def execute_activity(
            activity,
            *args,
            task_queue:,
            summary:,
            schedule_to_close_timeout:,
            schedule_to_start_timeout:,
            start_to_close_timeout:,
            heartbeat_timeout:,
            retry_policy:,
            cancellation:,
            cancellation_type:,
            activity_id:,
            disable_eager_execution:,
            priority:,
            arg_hints:,
            result_hint:
          )
            activity, defn_arg_hints, defn_result_hint =
              case activity
              when Class
                defn = Activity::Definition::Info.from_activity(activity)
                [defn.name&.to_s, defn.arg_hints, defn.result_hint]
              when Symbol, String
                [activity.to_s, nil, nil]
              else
                raise ArgumentError,
                      'Activity must be a definition class, or a symbol/string'
              end
            raise 'Cannot invoke dynamic activities' unless activity

            @outbound.execute_activity(
              Temporalio::Worker::Interceptor::Workflow::ExecuteActivityInput.new(
                activity:,
                args:,
                task_queue: task_queue || info.task_queue,
                summary:,
                schedule_to_close_timeout:,
                schedule_to_start_timeout:,
                start_to_close_timeout:,
                heartbeat_timeout:,
                retry_policy:,
                cancellation:,
                cancellation_type:,
                activity_id:,
                disable_eager_execution: disable_eager_execution || @instance.disable_eager_activity_execution,
                priority:,
                arg_hints: arg_hints || defn_arg_hints,
                result_hint: result_hint || defn_result_hint,
                headers: {}
              )
            )
          end

          def execute_local_activity(
            activity,
            *args,
            schedule_to_close_timeout:,
            schedule_to_start_timeout:,
            start_to_close_timeout:,
            retry_policy:,
            local_retry_threshold:,
            cancellation:,
            cancellation_type:,
            activity_id:,
            arg_hints:,
            result_hint:
          )
            activity, defn_arg_hints, defn_result_hint =
              case activity
              when Class
                defn = Activity::Definition::Info.from_activity(activity)
                [defn.name&.to_s, defn.arg_hints, defn.result_hint]
              when Symbol, String
                [activity.to_s, nil, nil]
              else
                raise ArgumentError, 'Activity must be a definition class, or a symbol/string'
              end
            raise 'Cannot invoke dynamic activities' unless activity

            @outbound.execute_local_activity(
              Temporalio::Worker::Interceptor::Workflow::ExecuteLocalActivityInput.new(
                activity:,
                args:,
                schedule_to_close_timeout:,
                schedule_to_start_timeout:,
                start_to_close_timeout:,
                retry_policy:,
                local_retry_threshold:,
                cancellation:,
                cancellation_type:,
                activity_id:,
                arg_hints: arg_hints || defn_arg_hints,
                result_hint: result_hint || defn_result_hint,
                headers: {}
              )
            )
          end

          def external_workflow_handle(workflow_id, run_id: nil)
            ExternalWorkflowHandle.new(id: workflow_id, run_id:, instance: @instance)
          end

          def illegal_call_tracing_disabled(&)
            @instance.illegal_call_tracing_disabled(&)
          end

          def info
            @instance.info
          end

          def instance
            @instance.instance
          end

          def initialize_continue_as_new_error(error)
            @outbound.initialize_continue_as_new_error(
              Temporalio::Worker::Interceptor::Workflow::InitializeContinueAsNewErrorInput.new(error:)
            )
          end

          def io_enabled(&)
            prev = @instance.io_enabled
            @instance.io_enabled = true
            begin
              yield
            ensure
              @instance.io_enabled = prev
            end
          end

          def logger
            @instance.logger
          end

          def memo
            @instance.memo
          end

          def metric_meter
            @instance.metric_meter
          end

          def now
            @instance.now
          end

          def patched(patch_id)
            @instance.patch(patch_id:, deprecated: false)
          end

          def payload_converter
            @instance.payload_converter
          end

          def query_handlers
            @instance.query_handlers
          end

          def random
            @instance.random
          end

          def replaying?
            @instance.replaying
          end

          def search_attributes
            @instance.search_attributes
          end

          def signal_handlers
            @instance.signal_handlers
          end

          def sleep(duration, summary:, cancellation:)
            @outbound.sleep(
              Temporalio::Worker::Interceptor::Workflow::SleepInput.new(
                duration:,
                summary:,
                cancellation:
              )
            )
          end

          def start_child_workflow(
            workflow,
            *args,
            id:,
            task_queue:,
            static_summary:,
            static_details:,
            cancellation:,
            cancellation_type:,
            parent_close_policy:,
            execution_timeout:,
            run_timeout:,
            task_timeout:,
            id_reuse_policy:,
            retry_policy:,
            cron_schedule:,
            memo:,
            search_attributes:,
            priority:,
            arg_hints:,
            result_hint:
          )
            workflow, defn_arg_hints, defn_result_hint =
              Workflow::Definition._workflow_type_and_hints_from_workflow_parameter(workflow)
            @outbound.start_child_workflow(
              Temporalio::Worker::Interceptor::Workflow::StartChildWorkflowInput.new(
                workflow:,
                args:,
                id:,
                task_queue:,
                static_summary:,
                static_details:,
                cancellation:,
                cancellation_type:,
                parent_close_policy:,
                execution_timeout:,
                run_timeout:,
                task_timeout:,
                id_reuse_policy:,
                retry_policy:,
                cron_schedule:,
                memo:,
                search_attributes:,
                priority:,
                arg_hints: arg_hints || defn_arg_hints,
                result_hint: result_hint || defn_result_hint,
                headers: {}
              )
            )
          end

          def storage
            @storage ||= {}
          end

          def timeout(duration, exception_class, *exception_args, summary:, &)
            raise 'Block required for timeout' unless block_given?

            # Run timer in background and block in foreground. This gives better stack traces than a future any-of race.
            # We make a detached cancellation because we don't want to link to workflow cancellation.
            sleep_cancel, sleep_cancel_proc = Cancellation.new
            fiber = Fiber.current
            Workflow::Future.new do
              Workflow.sleep(duration, summary:, cancellation: sleep_cancel)
              fiber.raise(exception_class, *exception_args) if fiber.alive? # steep:ignore
            rescue Exception => e # rubocop:disable Lint/RescueException
              # Re-raise in fiber
              fiber.raise(e) if fiber.alive?
            end

            begin
              yield
            ensure
              sleep_cancel_proc.call
            end
          end

          def update_handlers
            @instance.update_handlers
          end

          def upsert_memo(hash)
            # Convert to memo, apply updates, then add the command (so command adding is post validation)
            upserted_memo = ProtoUtils.memo_to_proto(hash, payload_converter)
            memo._update do |new_hash|
              hash.each do |key, val|
                # Nil means delete
                if val.nil?
                  new_hash.delete(key.to_s)
                else
                  new_hash[key.to_s] = val
                end
              end
            end
            @instance.add_command(
              Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                modify_workflow_properties: Bridge::Api::WorkflowCommands::ModifyWorkflowProperties.new(
                  upserted_memo:
                )
              )
            )
          end

          def upsert_search_attributes(*updates)
            # Apply updates then add the command (so command adding is post validation)
            search_attributes._disable_mutations = false
            search_attributes.update!(*updates)
            @instance.add_command(
              Bridge::Api::WorkflowCommands::WorkflowCommand.new(
                upsert_workflow_search_attributes: Bridge::Api::WorkflowCommands::UpsertWorkflowSearchAttributes.new(
                  search_attributes: updates.to_h(&:_to_proto_pair)
                )
              )
            )
          ensure
            search_attributes._disable_mutations = true
          end

          def wait_condition(cancellation:, &)
            @instance.scheduler.wait_condition(cancellation:, &)
          end

          def _cancel_external_workflow(id:, run_id:)
            @outbound.cancel_external_workflow(
              Temporalio::Worker::Interceptor::Workflow::CancelExternalWorkflowInput.new(id:, run_id:)
            )
          end

          def _outbound=(outbound)
            @outbound = outbound
          end

          def _signal_child_workflow(id:, signal:, args:, cancellation:, arg_hints:)
            signal, defn_arg_hints = Workflow::Definition::Signal._name_and_hints_from_parameter(signal)
            @outbound.signal_child_workflow(
              Temporalio::Worker::Interceptor::Workflow::SignalChildWorkflowInput.new(
                id:,
                signal:,
                args:,
                cancellation:,
                arg_hints: arg_hints || defn_arg_hints,
                headers: {}
              )
            )
          end

          def _signal_external_workflow(id:, run_id:, signal:, args:, cancellation:, arg_hints:)
            signal, defn_arg_hints = Workflow::Definition::Signal._name_and_hints_from_parameter(signal)
            @outbound.signal_external_workflow(
              Temporalio::Worker::Interceptor::Workflow::SignalExternalWorkflowInput.new(
                id:,
                run_id:,
                signal:,
                args:,
                cancellation:,
                arg_hints: arg_hints || defn_arg_hints,
                headers: {}
              )
            )
          end
        end
      end
    end
  end
end
