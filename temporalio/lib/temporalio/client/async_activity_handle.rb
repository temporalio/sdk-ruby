# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/activity_id_reference'
require 'temporalio/client/interceptor'
require 'temporalio/error'

module Temporalio
  class Client
    # Handle representing an external activity for completion and heartbeat. This is usually created via
    # {Client.async_activity_handle}.
    class AsyncActivityHandle
      # @return [String, nil] Task token if created with a task token. Mutually exclusive with {id_reference}.
      attr_reader :task_token

      # @return [ActivityIDReference, nil] Activity ID reference if created with one. Mutually exclusive with
      # {task_token}.
      attr_reader :id_reference

      # @!visibility private
      def initialize(client:, task_token:, id_reference:)
        @client = client
        @task_token = task_token
        @id_reference = id_reference
      end

      # Record a heartbeat for the activity.
      #
      # @param details [Array<Object>] Details of the heartbeat.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      def heartbeat(*details, rpc_options: nil)
        @client._impl.heartbeat_async_activity(Interceptor::HeartbeatAsyncActivityInput.new(
                                                 task_token_or_id_reference:,
                                                 details:,
                                                 rpc_options:
                                               ))
      end

      # Complete the activity.
      #
      # @param result [Object, nil] Result of the activity.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      def complete(result = nil, rpc_options: nil)
        @client._impl.complete_async_activity(Interceptor::CompleteAsyncActivityInput.new(
                                                task_token_or_id_reference:,
                                                result:,
                                                rpc_options:
                                              ))
      end

      # Fail the activity.
      #
      # @param error [Exception] Error for the activity.
      # @param last_heartbeat_details [Array<Object>] Last heartbeat details for the activity.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      def fail(error, last_heartbeat_details: [], rpc_options: nil)
        @client._impl.fail_async_activity(Interceptor::FailAsyncActivityInput.new(
                                            task_token_or_id_reference:,
                                            error:,
                                            last_heartbeat_details:,
                                            rpc_options:
                                          ))
      end

      # Report the activity as canceled.
      #
      # @param details [Array<Object>] Cancellation details.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [AsyncActivityCanceledError] If the activity has been canceled.
      def report_cancellation(*details, rpc_options: nil)
        @client._impl.report_cancellation_async_activity(Interceptor::ReportCancellationAsyncActivityInput.new(
                                                           task_token_or_id_reference:,
                                                           details:,
                                                           rpc_options:
                                                         ))
      end

      private

      def task_token_or_id_reference
        @task_token || @id_reference or raise
      end
    end
  end
end
