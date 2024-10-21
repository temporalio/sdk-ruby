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
