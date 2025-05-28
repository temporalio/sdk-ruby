# frozen_string_literal: true

module Temporalio
  class Client
    # Mixin for intercepting clients. Classes that +include+ this should implement their own {intercept_client} that
    # returns their own instance of {Outbound}.
    #
    # @note Input classes herein may get new required fields added and therefore the constructors of the Input classes
    # may change in backwards incompatible ways. Users should not try to construct Input classes themselves.
    module Interceptor
      # Method called when intercepting a client. This is called upon client creation.
      #
      # @param next_interceptor [Outbound] Next interceptor in the chain that should be called. This is usually passed
      #   to {Outbound} constructor.
      # @return [Outbound] Interceptor to be called for client calls.
      def intercept_client(next_interceptor)
        next_interceptor
      end

      # Input for {Outbound.start_workflow}.
      StartWorkflowInput = Data.define(
        :workflow,
        :args,
        :workflow_id,
        :task_queue,
        :static_summary,
        :static_details,
        :execution_timeout,
        :run_timeout,
        :task_timeout,
        :id_reuse_policy,
        :id_conflict_policy,
        :retry_policy,
        :cron_schedule,
        :memo,
        :search_attributes,
        :start_delay,
        :request_eager_start,
        :headers,
        :priority,
        :versioning_override,
        :rpc_options
      )

      # Input for {Outbound.start_update_with_start_workflow}.
      StartUpdateWithStartWorkflowInput = Data.define(
        :update_id,
        :update,
        :args,
        :wait_for_stage,
        :start_workflow_operation,
        :headers,
        :rpc_options
      )

      # Input for {Outbound.signal_with_start_workflow}.
      SignalWithStartWorkflowInput = Data.define(
        :signal,
        :args,
        :start_workflow_operation,
        # Headers intentionally not defined here, because they are not separate from start_workflow_operation
        :rpc_options
      )

      # Input for {Outbound.list_workflows}.
      ListWorkflowsInput = Data.define(
        :query,
        :rpc_options
      )

      # Input for {Outbound.count_workflows}.
      CountWorkflowsInput = Data.define(
        :query,
        :rpc_options
      )

      # Input for {Outbound.describe_workflow}.
      DescribeWorkflowInput = Data.define(
        :workflow_id,
        :run_id,
        :rpc_options
      )

      # Input for {Outbound.fetch_workflow_history_events}.
      FetchWorkflowHistoryEventsInput = Data.define(
        :workflow_id,
        :run_id,
        :wait_new_event,
        :event_filter_type,
        :skip_archival,
        :rpc_options
      )

      # Input for {Outbound.signal_workflow}.
      SignalWorkflowInput = Data.define(
        :workflow_id,
        :run_id,
        :signal,
        :args,
        :headers,
        :rpc_options
      )

      # Input for {Outbound.query_workflow}.
      QueryWorkflowInput = Data.define(
        :workflow_id,
        :run_id,
        :query,
        :args,
        :reject_condition,
        :headers,
        :rpc_options
      )

      # Input for {Outbound.start_workflow_update}.
      StartWorkflowUpdateInput = Data.define(
        :workflow_id,
        :run_id,
        :update_id,
        :update,
        :args,
        :wait_for_stage,
        :headers,
        :rpc_options
      )

      # Input for {Outbound.poll_workflow_update}.
      PollWorkflowUpdateInput = Data.define(
        :workflow_id,
        :run_id,
        :update_id,
        :rpc_options
      )

      # Input for {Outbound.cancel_workflow}.
      CancelWorkflowInput = Data.define(
        :workflow_id,
        :run_id,
        :first_execution_run_id,
        :rpc_options
      )

      # Input for {Outbound.terminate_workflow}.
      TerminateWorkflowInput = Data.define(
        :workflow_id,
        :run_id,
        :first_execution_run_id,
        :reason,
        :details,
        :rpc_options
      )

      # Input for {Outbound.create_schedule}.
      CreateScheduleInput = Data.define(
        :id,
        :schedule,
        :trigger_immediately,
        :backfills,
        :memo,
        :search_attributes,
        :rpc_options
      )

      # Input for {Outbound.list_schedules}.
      ListSchedulesInput = Data.define(
        :query,
        :rpc_options
      )

      # Input for {Outbound.backfill_schedule}.
      BackfillScheduleInput = Data.define(
        :id,
        :backfills,
        :rpc_options
      )

      # Input for {Outbound.delete_schedule}.
      DeleteScheduleInput = Data.define(
        :id,
        :rpc_options
      )

      # Input for {Outbound.describe_schedule}.
      DescribeScheduleInput = Data.define(
        :id,
        :rpc_options
      )

      # Input for {Outbound.pause_schedule}.
      PauseScheduleInput = Data.define(
        :id,
        :note,
        :rpc_options
      )

      # Input for {Outbound.trigger_schedule}.
      TriggerScheduleInput = Data.define(
        :id,
        :overlap,
        :rpc_options
      )

      # Input for {Outbound.unpause_schedule}.
      UnpauseScheduleInput = Data.define(
        :id,
        :note,
        :rpc_options
      )

      # Input for {Outbound.update_schedule}.
      UpdateScheduleInput = Data.define(
        :id,
        :updater,
        :rpc_options
      )

      # Input for {Outbound.heartbeat_async_activity}.
      HeartbeatAsyncActivityInput = Data.define(
        :task_token_or_id_reference,
        :details,
        :rpc_options
      )

      # Input for {Outbound.complete_async_activity}.
      CompleteAsyncActivityInput = Data.define(
        :task_token_or_id_reference,
        :result,
        :rpc_options
      )

      # Input for {Outbound.fail_async_activity}.
      FailAsyncActivityInput = Data.define(
        :task_token_or_id_reference,
        :error,
        :last_heartbeat_details,
        :rpc_options
      )

      # Input for {Outbound.report_cancellation_async_activity}.
      ReportCancellationAsyncActivityInput = Data.define(
        :task_token_or_id_reference,
        :details,
        :rpc_options
      )

      # Outbound interceptor for intercepting client calls. This should be extended by users needing to intercept client
      # actions.
      class Outbound
        # @return [Outbound] Next interceptor in the chain.
        attr_reader :next_interceptor

        # Initialize outbound with the next interceptor in the chain.
        #
        # @param next_interceptor [Outbound] Next interceptor in the chain.
        def initialize(next_interceptor)
          @next_interceptor = next_interceptor
        end

        # Called for every {Client.start_workflow} and {Client.execute_workflow} call.
        #
        # @param input [StartWorkflowInput] Input.
        # @return [WorkflowHandle] Workflow handle.
        def start_workflow(input)
          next_interceptor.start_workflow(input)
        end

        # Called for every {Client.start_update_with_start_workflow} and {Client.execute_update_with_start_workflow}
        # call.
        #
        # @param input [StartUpdateWithStartWorkflowInput] Input.
        # @return [WorkflowUpdateHandle] Workflow update handle.
        def start_update_with_start_workflow(input)
          next_interceptor.start_update_with_start_workflow(input)
        end

        # Called for every {Client.signal_with_start_workflow}.
        #
        # @param input [SignalWithStartWorkflowInput] Input.
        # @return [WorkflowHandle] Workflow handle.
        def signal_with_start_workflow(input)
          next_interceptor.signal_with_start_workflow(input)
        end

        # Called for every {Client.list_workflows} call.
        #
        # @param input [ListWorkflowsInput] Input.
        # @return [Enumerator<WorkflowExecution>] Enumerable workflow executions.
        def list_workflows(input)
          next_interceptor.list_workflows(input)
        end

        # Called for every {Client.count_workflows} call.
        #
        # @param input [CountWorkflowsInput] Input.
        # @return [WorkflowExecutionCount] Workflow count.
        def count_workflows(input)
          next_interceptor.count_workflows(input)
        end

        # Called for every {WorkflowHandle.describe} call.
        #
        # @param input [DescribeWorkflowInput] Input.
        # @return [WorkflowExecution::Description] Workflow description.
        def describe_workflow(input)
          next_interceptor.describe_workflow(input)
        end

        # Called everytime the client needs workflow history. This includes getting the result.
        #
        # @param input [FetchWorkflowHistoryEventsInput] Input.
        # @return [Enumerator<Api::History::V1::HistoryEvent>] Event enumerator.
        def fetch_workflow_history_events(input)
          next_interceptor.fetch_workflow_history_events(input)
        end

        # Called for every {WorkflowHandle.signal} call.
        #
        # @param input [SignalWorkflowInput] Input.
        def signal_workflow(input)
          next_interceptor.signal_workflow(input)
        end

        # Called for every {WorkflowHandle.query} call.
        #
        # @param input [QueryWorkflowInput] Input.
        # @return [Object, nil] Query result.
        def query_workflow(input)
          next_interceptor.query_workflow(input)
        end

        # Called for every {WorkflowHandle.start_update} call.
        #
        # @param input [StartWorkflowUpdateInput] Input.
        # @return [WorkflowUpdateHandle] Update handle.
        def start_workflow_update(input)
          next_interceptor.start_workflow_update(input)
        end

        # Called when polling for update result.
        #
        # @param input [PollWorkflowUpdateInput] Input.
        # @return [Api::Update::V1::Outcome] Update outcome.
        def poll_workflow_update(input)
          next_interceptor.poll_workflow_update(input)
        end

        # Called for every {WorkflowHandle.cancel} call.
        #
        # @param input [CancelWorkflowInput] Input.
        def cancel_workflow(input)
          next_interceptor.cancel_workflow(input)
        end

        # Called for every {WorkflowHandle.terminate} call.
        #
        # @param input [TerminateWorkflowInput] Input.
        def terminate_workflow(input)
          next_interceptor.terminate_workflow(input)
        end

        # Called for every {Client.create_schedule} call.
        #
        # @param input [CreateScheduleInput] Input.
        # @return [ScheduleHandle] Schedule handle.
        def create_schedule(input)
          next_interceptor.create_schedule(input)
        end

        # Called for every {Client.list_schedules} call.
        #
        # @param input [ListSchedulesInput] Input.
        # @return [Enumerator<Schedule::List::Description>] Enumerable schedules.
        def list_schedules(input)
          next_interceptor.list_schedules(input)
        end

        # Called for every {ScheduleHandle.backfill} call.
        #
        # @param input [BackfillScheduleInput] Input.
        def backfill_schedule(input)
          next_interceptor.backfill_schedule(input)
        end

        # Called for every {ScheduleHandle.delete} call.
        #
        # @param input [DeleteScheduleInput] Input.
        def delete_schedule(input)
          next_interceptor.delete_schedule(input)
        end

        # Called for every {ScheduleHandle.describe} call.
        #
        # @param input [DescribeScheduleInput] Input.
        # @return [Schedule::Description] Schedule description.
        def describe_schedule(input)
          next_interceptor.describe_schedule(input)
        end

        # Called for every {ScheduleHandle.pause} call.
        #
        # @param input [PauseScheduleInput] Input.
        def pause_schedule(input)
          next_interceptor.pause_schedule(input)
        end

        # Called for every {ScheduleHandle.trigger} call.
        #
        # @param input [TriggerScheduleInput] Input.
        def trigger_schedule(input)
          next_interceptor.trigger_schedule(input)
        end

        # Called for every {ScheduleHandle.unpause} call.
        #
        # @param input [UnpauseScheduleInput] Input.
        def unpause_schedule(input)
          next_interceptor.unpause_schedule(input)
        end

        # Called for every {ScheduleHandle.update} call.
        #
        # @param input [UpdateScheduleInput] Input.
        def update_schedule(input)
          next_interceptor.update_schedule(input)
        end

        # Called for every {AsyncActivityHandle.heartbeat} call.
        #
        # @param input [HeartbeatAsyncActivityInput] Input.
        def heartbeat_async_activity(input)
          next_interceptor.heartbeat_async_activity(input)
        end

        # Called for every {AsyncActivityHandle.complete} call.
        #
        # @param input [CompleteAsyncActivityInput] Input.
        def complete_async_activity(input)
          next_interceptor.complete_async_activity(input)
        end

        # Called for every {AsyncActivityHandle.fail} call.
        #
        # @param input [FailAsyncActivityInput] Input.
        def fail_async_activity(input)
          next_interceptor.fail_async_activity(input)
        end

        # Called for every {AsyncActivityHandle.report_cancellation} call.
        #
        # @param input [ReportCancellationAsyncActivityInput] Input.
        def report_cancellation_async_activity(input)
          next_interceptor.report_cancellation_async_activity(input)
        end
      end
    end
  end
end
