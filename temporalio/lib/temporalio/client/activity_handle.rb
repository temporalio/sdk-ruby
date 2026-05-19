# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/activity_execution'
require 'temporalio/client/interceptor'
require 'temporalio/error'

module Temporalio
  class Client
    # Handle for interacting with a standalone activity. Usually created via {Client.activity_handle}
    # or {Client#start_activity}.
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

      # Wait for the activity's outcome (result or failure). Long-polls PollActivityExecution
      # internally until the activity reaches a terminal state.
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
        outcome = @client._impl.fetch_activity_outcome(
          Interceptor::FetchActivityOutcomeInput.new(
            activity_id: id,
            activity_run_id: run_id,
            rpc_options:
          )
        )
        _process_outcome(outcome, hint)
      end

      # Describe the activity (one-shot, no long-poll).
      #
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @return [ActivityExecution::Description] Activity description.
      # @raise [Error::RPCError] RPC error from call.
      def describe(rpc_options: nil)
        @client._impl.describe_activity(
          Interceptor::DescribeActivityInput.new(
            activity_id: id,
            activity_run_id: run_id,
            rpc_options:
          )
        )
      end

      # Request cancellation of the activity.
      #
      # @param reason [String, nil] Optional cancellation reason recorded on the server.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def cancel(reason = nil, rpc_options: nil)
        @client._impl.cancel_activity(
          Interceptor::CancelActivityInput.new(
            activity_id: id,
            activity_run_id: run_id,
            reason:,
            rpc_options:
          )
        )
        nil
      end

      # Terminate the activity (force-close).
      #
      # @param reason [String, nil] Optional termination reason recorded on the activity's failure outcome.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def terminate(reason = nil, rpc_options: nil)
        @client._impl.terminate_activity(
          Interceptor::TerminateActivityInput.new(
            activity_id: id,
            activity_run_id: run_id,
            reason:,
            rpc_options:
          )
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
