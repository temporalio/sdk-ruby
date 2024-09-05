# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/interceptor'
require 'temporalio/error'

module Temporalio
  class Client
    # Handle for interacting with a workflow. This is usually created via {Client.start_workflow} or
    # {Client.workflow_handle}.
    class WorkflowHandle
      # @return [String] ID for the workflow.
      attr_reader :id

      # Run ID used for {signal}, {query}, and {update} calls if present to ensure the signal/query/update happen on
      # this exact run.
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

      # Create a workflow handle. {Client.workflow_handle} is preferred over instantiating this directly.
      def initialize(client, id, run_id: nil, result_run_id: nil, first_execution_run_id: nil)
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
      # @raise [Error::WorkflowFailureError] Workflow failed with {Error::WorkflowFailureError#cause} as cause.
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
          event = fetch_history_events_for_run(
            hist_run_id,
            page_size: nil,
            wait_new_event: true,
            event_filter_type: Api::Enums::V1::HistoryEventFilterType::HISTORY_EVENT_FILTER_TYPE_CLOSE_EVENT,
            skip_archival: true,
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

            raise Error::WorkflowFailureError.new(cause: @client.data_converter.from_failure(attrs.failure))
          when :EVENT_TYPE_WORKFLOW_EXECUTION_CANCELED
            attrs = event.workflow_execution_canceled_event_attributes
            raise Error::WorkflowFailureError.new(
              cause: Error::CancelledError.new(
                'Workflow execution cancelled',
                details: @client.data_converter.from_payloads(attrs&.details)
              )
            )
          when :EVENT_TYPE_WORKFLOW_EXECUTION_TERMINATED
            attrs = event.workflow_execution_terminated_event_attributes
            raise Error::WorkflowFailureError.new(
              cause: Error::TerminatedError.new(
                attrs.reason.empty? ? 'Workflow execution cancelled' : attrs.reason,
                details: @client.data_converter.from_payloads(attrs&.details)
              )
            )
          when :EVENT_TYPE_WORKFLOW_EXECUTION_TIMED_OUT
            attrs = event.workflow_execution_timed_out_event_attributes
            hist_run_id = attrs.new_execution_run_id
            next if follow_runs && hist_run_id && !hist_run_id.empty?

            raise Error::WorkflowFailureError.new(
              cause: Error::TimeoutError.new(
                'Workflow execution timed out',
                type: Api::Enums::V1::TimeoutType::TIMEOUT_TYPE_START_TO_CLOSE
              )
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

      # Fetch an enumerable of history events for this workflow. Internally this is done in paginated form, but it is
      # presented as an enumerable.
      #
      # @param page_size [Integer, nil] Page size for each internal page fetch. Most users will not need to set this
      #   since the enumerable hides pagination.
      # @param wait_new_event [Boolean] If +true+, when the end of the current set of events is reached but the workflow
      #   is not complete, this will wait for the next event. If +false+, the enumerable completes at the end of current
      #   history.
      # @param event_filter_type [Api::Enums::V1::HistoryEventFilterType] Types of events to fetch.
      # @param skip_archival [Boolean] Whether to skip archival.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      #
      # @return [Enumerable<Api::History::V1::HistoryEvent>] Enumerable events.
      def fetch_history_events(
        page_size: nil,
        wait_new_event: false,
        event_filter_type: Api::Enums::V1::HistoryEventFilterType::HISTORY_EVENT_FILTER_TYPE_ALL_EVENT,
        skip_archival: false,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        fetch_history_events_for_run(
          run_id,
          page_size:,
          wait_new_event:,
          event_filter_type:,
          skip_archival:,
          rpc_metadata:,
          rpc_timeout:
        )
      end

      private

      def fetch_history_events_for_run(
        run_id,
        page_size:,
        wait_new_event:,
        event_filter_type:,
        skip_archival:,
        rpc_metadata:,
        rpc_timeout:
      )
        Enumerator.new do |yielder|
          input = Interceptor::FetchWorkflowHistoryEventPageInput.new(
            id:,
            run_id:,
            page_size:,
            next_page_token: nil,
            wait_new_event:,
            event_filter_type:,
            skip_archival:,
            rpc_metadata:,
            rpc_timeout:
          )
          loop do
            page = @client._impl.fetch_workflow_history_event_page(input)
            page.events.each { |event| yielder << event }
            break unless page.next_page_token

            input.next_page_token = page.next_page_token
          end
        end
      end
    end
  end
end
