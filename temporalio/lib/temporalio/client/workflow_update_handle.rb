# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/interceptor'
require 'temporalio/error'

module Temporalio
  class Client
    # Handle for a workflow update execution request. This is usually created via {WorkflowHandle.start_update} or
    # {WorkflowHandle.update_handle}.
    class WorkflowUpdateHandle
      # @return [String] ID for the workflow update.
      attr_reader :id

      # @return [String] ID for the workflow.
      attr_reader :workflow_id

      # @return [String, nil] Run ID for the workflow.
      attr_reader :workflow_run_id

      # @return [Object, nil] Result hint if one set when the handle was created.
      attr_reader :result_hint

      # @!visibility private
      def initialize(client:, id:, workflow_id:, workflow_run_id:, known_outcome:, result_hint:)
        @client = client
        @id = id
        @workflow_id = workflow_id
        @workflow_run_id = workflow_run_id
        @known_outcome = known_outcome
        @result_hint = result_hint
      end

      # @return [Boolean] True if the result is already known and {result} will not make a blocking call, false if
      #   {result} will make a blocking call because the result is not yet known.
      def result_obtained?
        !@known_outcome.nil?
      end

      # Wait for and return the result of the update. The result may already be known in which case no network call is
      # made. Otherwise the result will be polled for until it is returned.
      #
      # @param result_hint [Object, nil] If not nil, overrides handle-level result hint for getting the result.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @return [Object, nil] Update result.
      #
      # @raise [Error::WorkflowUpdateFailedError] If the update failed.
      # @raise [Error::WorkflowUpdateRPCTimeoutOrCanceledError] This update call timed out or was canceled. This doesn't
      #   mean the update itself was timed out or canceled.
      # @raise [Error::RPCError] RPC error from call.
      def result(result_hint: nil, rpc_options: nil)
        @known_outcome ||= @client._impl.poll_workflow_update(Interceptor::PollWorkflowUpdateInput.new(
                                                                workflow_id:,
                                                                run_id: workflow_run_id,
                                                                update_id: id,
                                                                rpc_options:
                                                              ))

        if @known_outcome.failure
          raise Error::WorkflowUpdateFailedError.new, cause: @client.data_converter.from_failure(@known_outcome.failure)
        end

        results = @client.data_converter.from_payloads(@known_outcome.success,
                                                       hints: Array(result_hint || @result_hint))
        warn("Expected 0 or 1 update result, got #{results.size}") if results.size > 1
        results.first
      end
    end
  end
end
