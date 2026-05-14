# frozen_string_literal: true

require 'securerandom'
require 'temporalio/api'
require 'temporalio/client/activity_execution'
require 'temporalio/error'

module Temporalio
  class Client
    # Handle for interacting with a standalone activity. This is usually created via
    # {Client.activity_handle}, or via `Client#start_activity` (step 3).
    #
    # Calls bridge RPCs directly through {Client::Connection}'s `workflow_service` plumbing.
    # Step 4 of the SAA plan will refactor these to flow through the interceptor chain.
    class ActivityHandle
      # @return [String] ID for the activity.
      attr_reader :id

      # @return [String, nil] Run ID for this activity execution. Nil targets the latest run.
      attr_reader :run_id

      # @return [Object, nil] Result hint used when deserializing the activity's result. May be overridden per
      #   {#result} call.
      attr_reader :result_hint

      # @!visibility private
      def initialize(client:, id:, run_id:, result_hint:)
        @client = client
        @id = id
        @run_id = run_id
        @result_hint = result_hint
      end

      # Wait for the activity's outcome (result or failure). Long-polls describe_activity_execution
      # internally, looping until the server returns an empty long-poll token (meaning the activity is
      # complete).
      #
      # @param result_hint [Object, nil] Override the result hint. If nil, uses {#result_hint}.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @return [Object, nil] Deserialized activity result.
      #
      # @raise [Error::ActivityFailedError] With +cause+ populated from the activity failure.
      # @raise [Error::RPCError] RPC error from call.
      def result(result_hint: nil, rpc_options: nil)
        hint = result_hint || @result_hint
        req = Api::WorkflowService::V1::DescribeActivityExecutionRequest.new(
          namespace: @client.namespace,
          activity_id: @id,
          run_id: @run_id || '',
          include_outcome: true
        )
        loop do
          resp = @client.workflow_service.describe_activity_execution(req, rpc_options:)
          unless resp.long_poll_token.empty?
            # Activity is still running; re-poll using the token.
            req.long_poll_token = resp.long_poll_token
            # The token implies run_id must also be present on the next request.
            req.run_id = resp.run_id unless resp.run_id.empty?
            next
          end
          # Activity is complete. Process the outcome.
          return _process_outcome(resp.outcome, hint)
        end
      end

      # Describe the activity (one-shot, no long-poll).
      #
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @return [ActivityExecution::Description] Activity description.
      # @raise [Error::RPCError] RPC error from call.
      def describe(rpc_options: nil)
        resp = @client.workflow_service.describe_activity_execution(
          Api::WorkflowService::V1::DescribeActivityExecutionRequest.new(
            namespace: @client.namespace,
            activity_id: @id,
            run_id: @run_id || ''
          ),
          rpc_options:
        )
        ActivityExecution::Description.new(resp, @client.data_converter)
      end

      # Request cancellation of the activity.
      #
      # @param reason [String, nil] Optional cancellation reason recorded on the server.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def cancel(reason = nil, rpc_options: nil)
        @client.workflow_service.request_cancel_activity_execution(
          Api::WorkflowService::V1::RequestCancelActivityExecutionRequest.new(
            namespace: @client.namespace,
            activity_id: @id,
            run_id: @run_id || '',
            identity: @client.connection.identity,
            request_id: SecureRandom.uuid,
            reason: reason || ''
          ),
          rpc_options:
        )
        nil
      end

      # Terminate the activity (force-close).
      #
      # @param reason [String, nil] Optional termination reason recorded on the activity's failure outcome.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def terminate(reason = nil, rpc_options: nil)
        @client.workflow_service.terminate_activity_execution(
          Api::WorkflowService::V1::TerminateActivityExecutionRequest.new(
            namespace: @client.namespace,
            activity_id: @id,
            run_id: @run_id || '',
            identity: @client.connection.identity,
            request_id: SecureRandom.uuid,
            reason: reason || ''
          ),
          rpc_options:
        )
        nil
      end

      private

      def _process_outcome(outcome, hint)
        if outcome.nil?
          raise Error, 'Activity completed but outcome is missing from server response'
        end

        case outcome.value
        when :failure
          cause = @client.data_converter.from_failure(outcome.failure)
          raise Error::ActivityFailedError.new, cause: cause
        when :result
          @client.data_converter.from_payloads(outcome.result, hints: Array(hint)).first
        else
          raise Error, "Unknown activity outcome: #{outcome.value.inspect}"
        end
      end
    end
  end
end
