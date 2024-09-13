# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/interceptor'
require 'temporalio/client/workflow_update_handle'
require 'temporalio/client/workflow_update_wait_stage'
require 'temporalio/error'
require 'temporalio/workflow_history'

module Temporalio
  class Client
    # Handle for interacting with a workflow. This is usually created via {Client.start_workflow} or
    # {Client.workflow_handle}.
    class WorkflowHandle
      # @return [String] ID for the workflow.
      attr_reader :id

      # Run ID used for {signal}, {query}, and {start_update}/{execute_update} calls if present to ensure the
      # signal/query/update happen on this exact run.
      #
      # This is only created via {Client.workflow_handle}. {Client.start_workflow} will not set this value.
      #
      # This cannot be mutated. If a different run ID is needed, {Client.workflow_handle} must be used instead.
      #
      # @return [String, nil] Run ID.
      attr_reader :run_id

      # Run ID used for {result} calls if present to ensure result is for a workflow starting from this run.
      #
      # When this handle is created via {Client.workflow_handle}, this is the same as {run_id}. When this handle is
      # created via {Client.start_workflow}, this value will be the resulting run ID.
      #
      # This cannot be mutated. If a different run ID is needed, {Client.workflow_handle} must be used instead.
      #
      # @return [String, nil] Result run ID.
      attr_reader :result_run_id

      # Run ID used for some calls like {cancel} and {terminate} to ensure the cancel and terminate happen for a
      # workflow ID on a chain started with this run ID.
      #
      # This can be set when using {Client.workflow_handle}. When {Client.start_workflow} is called without a start
      # signal, this is set to the resulting run.
      #
      # This cannot be mutated. If a different first execution run ID is needed, {Client.workflow_handle} must be used
      # instead.
      #
      # @return [String, nil] First execution run ID.
      attr_reader :first_execution_run_id

      # @!visibility private
      def initialize(client:, id:, run_id:, result_run_id:, first_execution_run_id:)
        @client = client
        @id = id
        @run_id = run_id
        @result_run_id = result_run_id
        @first_execution_run_id = first_execution_run_id
      end

      # Wait for the result of the workflow.
      #
      # This will use {result_run_id} if present to base the result on. To use another run ID, a new handle must be
      # created via {Client.workflow_handle}.
      #
      # @param follow_runs [Boolean] If +true+, workflow runs will be continually fetched across retries and continue as
      #   new until the latest one is found. If +false+, the first result is used.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @return [Object] Result of the workflow after being converted by the data converter.
      #
      # @raise [Error::WorkflowFailureError] Workflow failed with +cause+ as the cause.
      # @raise [Error::WorkflowContinuedAsNewError] Workflow continued as new and +follow_runs+ is +false+.
      # @raise [Error::RPCError] RPC error from call.
      def result(
        follow_runs: true,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        # Wait on the close event, following as needed
        hist_run_id = result_run_id
        loop do
          # Get close event
          event = fetch_history_events(
            wait_new_event: true,
            event_filter_type: Api::Enums::V1::HistoryEventFilterType::HISTORY_EVENT_FILTER_TYPE_CLOSE_EVENT,
            skip_archival: true,
            specific_run_id: hist_run_id,
            rpc_metadata:,
            rpc_timeout:
          ).next

          # Check each close type'
          case event.event_type
          when :EVENT_TYPE_WORKFLOW_EXECUTION_COMPLETED
            attrs = event.workflow_execution_completed_event_attributes
            hist_run_id = attrs.new_execution_run_id
            next if follow_runs && hist_run_id && !hist_run_id.empty?

            return @client.data_converter.from_payloads(attrs.result).first
          when :EVENT_TYPE_WORKFLOW_EXECUTION_FAILED
            attrs = event.workflow_execution_failed_event_attributes
            hist_run_id = attrs.new_execution_run_id
            next if follow_runs && hist_run_id && !hist_run_id.empty?

            raise Error::WorkflowFailureError.new, cause: @client.data_converter.from_failure(attrs.failure)
          when :EVENT_TYPE_WORKFLOW_EXECUTION_CANCELED
            attrs = event.workflow_execution_canceled_event_attributes
            raise Error::WorkflowFailureError.new, cause: Error::CanceledError.new(
              'Workflow execution canceled',
              details: @client.data_converter.from_payloads(attrs&.details)
            )
          when :EVENT_TYPE_WORKFLOW_EXECUTION_TERMINATED
            attrs = event.workflow_execution_terminated_event_attributes
            raise Error::WorkflowFailureError.new, cause: Error::TerminatedError.new(
              Internal::ProtoUtils.string_or(attrs.reason, 'Workflow execution terminated'),
              details: @client.data_converter.from_payloads(attrs&.details)
            )
          when :EVENT_TYPE_WORKFLOW_EXECUTION_TIMED_OUT
            attrs = event.workflow_execution_timed_out_event_attributes
            hist_run_id = attrs.new_execution_run_id
            next if follow_runs && hist_run_id && !hist_run_id.empty?

            raise Error::WorkflowFailureError.new, cause: Error::TimeoutError.new(
              'Workflow execution timed out',
              type: Api::Enums::V1::TimeoutType::TIMEOUT_TYPE_START_TO_CLOSE,
              last_heartbeat_details: []
            )
          when :EVENT_TYPE_WORKFLOW_EXECUTION_CONTINUED_AS_NEW
            attrs = event.workflow_execution_continued_as_new_event_attributes
            hist_run_id = attrs.new_execution_run_id
            next if follow_runs && hist_run_id && !hist_run_id.empty?

            # TODO: Use more specific error and decode failure
            raise Error::WorkflowContinuedAsNewError.new(new_run_id: attrs.new_execution_run_id)
          else
            raise Error, "Unknown close event type: #{event.event_type}"
          end
        end
      end

      # Get workflow details. This will get details for the {run_id} if present. To use a different run ID, create a new
      # handle via {Client.workflow_handle}.
      #
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @return [WorkflowExecution::Description] Workflow description.
      #
      # @raise [Error::RPCError] RPC error from call.
      #
      # @note Handles created as a result of {Client.start_workflow} will describe the latest workflow with the same
      #   workflow ID even if it is unrelated to the started workflow.
      def describe(
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        @client._impl.describe_workflow(Interceptor::DescribeWorkflowInput.new(
                                          workflow_id: id,
                                          run_id:,
                                          rpc_metadata:,
                                          rpc_timeout:
                                        ))
      end

      # Get workflow history. This is a helper on top of {fetch_history_events}.
      #
      # @param event_filter_type [Api::Enums::V1::HistoryEventFilterType] Types of events to fetch.
      # @param skip_archival [Boolean] Whether to skip archival.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @return [WorkflowHistory] Workflow history.
      #
      # @raise [Error::RPCError] RPC error from call.
      def fetch_history(
        event_filter_type: Api::Enums::V1::HistoryEventFilterType::HISTORY_EVENT_FILTER_TYPE_ALL_EVENT,
        skip_archival: false,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        WorkflowHistory.new(
          fetch_history_events(
            event_filter_type:,
            skip_archival:,
            rpc_metadata:,
            rpc_timeout:
          ).to_a
        )
      end

      # Fetch an enumerator of history events for this workflow. Internally this is done in paginated form, but it is
      # presented as an enumerator.
      #
      # @param wait_new_event [Boolean] If +true+, when the end of the current set of events is reached but the workflow
      #   is not complete, this will wait for the next event. If +false+, the enumerable completes at the end of current
      #   history.
      # @param event_filter_type [Api::Enums::V1::HistoryEventFilterType] Types of events to fetch.
      # @param skip_archival [Boolean] Whether to skip archival.
      # @param specific_run_id [String, nil] Run ID to fetch events for. Default is the {run_id}. Most users will not
      #   need to set this and instead use the one on the class.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @return [Enumerator<Api::History::V1::HistoryEvent>] Enumerable events.
      #
      # @raise [Error::RPCError] RPC error from call.
      def fetch_history_events(
        wait_new_event: false,
        event_filter_type: Api::Enums::V1::HistoryEventFilterType::HISTORY_EVENT_FILTER_TYPE_ALL_EVENT,
        skip_archival: false,
        specific_run_id: run_id,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        @client._impl.fetch_workflow_history_events(Interceptor::FetchWorkflowHistoryEventsInput.new(
                                                      workflow_id: id,
                                                      run_id: specific_run_id,
                                                      wait_new_event:,
                                                      event_filter_type:,
                                                      skip_archival:,
                                                      rpc_metadata:,
                                                      rpc_timeout:
                                                    ))
      end

      # Send a signal to the workflow. This will signal for {run_id} if present. To use a different run ID, create a new
      # handle via {Client.workflow_handle}.
      #
      # @param signal [String] Signal name.
      # @param args [Array<Object>] Signal arguments.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @raise [Error::RPCError] RPC error from call.
      #
      # @note Handles created as a result of {Client.start_workflow} will signal the latest workflow with the same
      #   workflow ID even if it is unrelated to the started workflow.
      def signal(
        signal,
        *args,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        @client._impl.signal_workflow(Interceptor::SignalWorkflowInput.new(
                                        workflow_id: id,
                                        run_id:,
                                        signal:,
                                        args:,
                                        headers: {},
                                        rpc_metadata:,
                                        rpc_timeout:
                                      ))
      end

      # Query the workflow. This will query for {run_id} if present. To use a different run ID, create a new handle via
      # {Client.workflow_handle}.
      #
      # @param query [String] Query name.
      # @param args [Array<Object>] Query arguments.
      # @param reject_condition [WorkflowQueryRejectCondition, nil] Condition for rejecting the query.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @return [Object, nil] Query result.
      #
      # @raise [Error::WorkflowQueryFailedError] The query on the workflow returned a failure.
      # @raise [Error::WorkflowQueryRejectedError] A query reject condition was satisfied.
      # @raise [Error::RPCError] RPC error from call.
      #
      # @note Handles created as a result of {Client.start_workflow} will query the latest workflow with the same
      #   workflow ID even if it is unrelated to the started workflow.
      def query(
        query,
        *args,
        reject_condition: @client.options.default_workflow_query_reject_condition,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        @client._impl.query_workflow(Interceptor::QueryWorkflowInput.new(
                                       workflow_id: id,
                                       run_id:,
                                       query:,
                                       args:,
                                       reject_condition:,
                                       headers: {},
                                       rpc_metadata:,
                                       rpc_timeout:
                                     ))
      end

      # Send an update request to the workflow and return a handle to it. This will target the workflow with {run_id} if
      # present. To use a different run ID, create a new handle via {Client.workflow_handle}.
      #
      # @param update [String] Update name.
      # @param args [Array<Object>] Update arguments.
      # @param wait_for_stage [WorkflowUpdateWaitStage] Required stage to wait until returning. ADMITTED is not
      #   currently supported. See https://docs.temporal.io/workflows#update for more details.
      # @param id [String] ID of the update.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @return [WorkflowUpdateHandle] The update handle.
      #
      # @raise [Error::WorkflowUpdateRPCTimeoutOrCanceledError] This update call timed out or was canceled. This doesn't
      #   mean the update itself was timed out or cancelled.
      # @raise [Error::RPCError] RPC error from call.
      #
      # @note Handles created as a result of {Client.start_workflow} will send updates the latest workflow with the same
      #   workflow ID even if it is unrelated to the started workflow.
      # @note WARNING: This API is experimental.
      def start_update(
        update,
        *args,
        wait_for_stage:,
        id: SecureRandom.uuid,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        @client._impl.start_workflow_update(Interceptor::StartWorkflowUpdateInput.new(
                                              workflow_id: self.id,
                                              run_id:,
                                              update_id: id,
                                              update:,
                                              args:,
                                              wait_for_stage:,
                                              headers: {},
                                              rpc_metadata:,
                                              rpc_timeout:
                                            ))
      end

      # Send an update request to the workflow and wait for it to complete. This will target the workflow with {run_id}
      # if present. To use a different run ID, create a new handle via {Client.workflow_handle}.
      #
      # @param update [String] Update name.
      # @param args [Array<Object>] Update arguments.
      # @param id [String] ID of the update.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @return [Object, nil] Update result.
      #
      # @raise [Error::WorkflowUpdateFailedError] If the update failed.
      # @raise [Error::WorkflowUpdateRPCTimeoutOrCanceledError] This update call timed out or was canceled. This doesn't
      #   mean the update itself was timed out or cancelled.
      # @raise [Error::RPCError] RPC error from call.
      #
      # @note Handles created as a result of {Client.start_workflow} will send updates the latest workflow with the same
      #   workflow ID even if it is unrelated to the started workflow.
      # @note WARNING: This API is experimental.
      def execute_update(
        update,
        *args,
        id: SecureRandom.uuid,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        start_update(
          update,
          *args,
          wait_for_stage: WorkflowUpdateWaitStage::COMPLETED,
          id:,
          rpc_metadata:,
          rpc_timeout:
        ).result
      end

      # Get a handle for an update. The handle can be used to wait on the update result.
      #
      # @param id [String] ID of the update.
      # @param specific_run_id [String, nil] Workflow run ID to get update handle for. Default is the {run_id}. Most
      #   users will not need to set this and instead use the one on the class.
      #
      # @return [WorkflowUpdateHandle] The update handle.
      #
      # @note WARNING: This API is experimental.
      def update_handle(
        id,
        specific_run_id: run_id
      )
        WorkflowUpdateHandle.new(
          client: @client,
          id:,
          workflow_id: self.id,
          workflow_run_id: specific_run_id,
          known_outcome: nil
        )
      end

      # Cancel the workflow. This will issue a cancellation for {run_id} if present. This call will make sure to use the
      # run chain starting from {first_execution_run_id} if present. To create handles with these values, use
      # {Client.workflow_handle}.
      #
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @raise [Error::RPCError] RPC error from call.
      #
      # @note Handles created as a result of signal with start will cancel the latest workflow with the same workflow ID
      #   even if it is unrelated to the started workflow.
      def cancel(
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        @client._impl.cancel_workflow(Interceptor::CancelWorkflowInput.new(
                                        workflow_id: id,
                                        run_id:,
                                        first_execution_run_id:,
                                        rpc_metadata:,
                                        rpc_timeout:
                                      ))
      end

      # Terminate the workflow. This will issue a termination for {run_id} if present. This call will make sure to use
      # the run chain starting from {first_execution_run_id} if present. To create handles with these values, use
      # {Client.workflow_handle}.
      #
      # @param reason [String, nil] Reason for the termination.
      # @param details [Array<Object>] Details to store on the termination.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @raise [Error::RPCError] RPC error from call.
      #
      # @note Handles created as a result of signal with start will terminate the latest workflow with the same workflow
      #   ID even if it is unrelated to the started workflow.
      def terminate(
        reason = nil,
        details: [],
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        @client._impl.terminate_workflow(Interceptor::TerminateWorkflowInput.new(
                                           workflow_id: id,
                                           run_id:,
                                           first_execution_run_id:,
                                           reason:,
                                           details:,
                                           rpc_metadata:,
                                           rpc_timeout:
                                         ))
      end
    end
  end
end
