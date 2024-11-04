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
      StartWorkflowInput = Struct.new(
        :workflow,
        :args,
        :workflow_id,
        :task_queue,
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
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.list_workflows}.
      ListWorkflowsInput = Struct.new(
        :query,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.count_workflows}.
      CountWorkflowsInput = Struct.new(
        :query,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.describe_workflow}.
      DescribeWorkflowInput = Struct.new(
        :workflow_id,
        :run_id,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.fetch_workflow_history_events}.
      FetchWorkflowHistoryEventsInput = Struct.new(
        :workflow_id,
        :run_id,
        :wait_new_event,
        :event_filter_type,
        :skip_archival,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.signal_workflow}.
      SignalWorkflowInput = Struct.new(
        :workflow_id,
        :run_id,
        :signal,
        :args,
        :headers,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.query_workflow}.
      QueryWorkflowInput = Struct.new(
        :workflow_id,
        :run_id,
        :query,
        :args,
        :reject_condition,
        :headers,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.start_workflow_update}.
      StartWorkflowUpdateInput = Struct.new(
        :workflow_id,
        :run_id,
        :update_id,
        :update,
        :args,
        :wait_for_stage,
        :headers,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.poll_workflow_update}.
      PollWorkflowUpdateInput = Struct.new(
        :workflow_id,
        :run_id,
        :update_id,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.cancel_workflow}.
      CancelWorkflowInput = Struct.new(
        :workflow_id,
        :run_id,
        :first_execution_run_id,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.terminate_workflow}.
      TerminateWorkflowInput = Struct.new(
        :workflow_id,
        :run_id,
        :first_execution_run_id,
        :reason,
        :details,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.create_schedule}.
      CreateScheduleInput = Struct.new(
        :id,
        :schedule,
        :trigger_immediately,
        :backfills,
        :memo,
        :search_attributes,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.list_schedules}.
      ListSchedulesInput = Struct.new(
        :query,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.backfill_schedule}.
      BackfillScheduleInput = Struct.new(
        :id,
        :backfills,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.delete_schedule}.
      DeleteScheduleInput = Struct.new(
        :id,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.describe_schedule}.
      DescribeScheduleInput = Struct.new(
        :id,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.pause_schedule}.
      PauseScheduleInput = Struct.new(
        :id,
        :note,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.trigger_schedule}.
      TriggerScheduleInput = Struct.new(
        :id,
        :overlap,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.unpause_schedule}.
      UnpauseScheduleInput = Struct.new(
        :id,
        :note,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.update_schedule}.
      UpdateScheduleInput = Struct.new(
        :id,
        :updater,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.heartbeat_async_activity}.
      HeartbeatAsyncActivityInput = Struct.new(
        :task_token_or_id_reference,
        :details,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.complete_async_activity}.
      CompleteAsyncActivityInput = Struct.new(
        :task_token_or_id_reference,
        :result,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.fail_async_activity}.
      FailAsyncActivityInput = Struct.new(
        :task_token_or_id_reference,
        :error,
        :last_heartbeat_details,
        :rpc_options,
        keyword_init: true
      )

      # Input for {Outbound.report_cancellation_async_activity}.
      ReportCancellationAsyncActivityInput = Struct.new(
        :task_token_or_id_reference,
        :details,
        :rpc_options,
        keyword_init: true
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
