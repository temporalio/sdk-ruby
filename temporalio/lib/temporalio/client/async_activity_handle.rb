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

      # Create an async activity handle. {Client.async_activity_handle} is preferred over instantiating this directly.
      def initialize(task_token_or_id_reference)
        if task_token_or_id_reference.is_a?(ActivityIDReference)
          @id_reference = task_token_or_id_reference
        elsif task_token_or_id_reference.is_a?(String)
          @task_token = task_token_or_id_reference
        else
          raise ArgumentError, 'Must be a string task token or an ActivityIDReference'
        end
      end

      # Record a heartbeat for the activity.
      #
      # @param details [Array<Object>] Details of the heartbeat.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      def heartbeat(
        *details,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        raise NotImplementedError
      end

      # Complete the activity.
      #
      # @param result [Object, nil] Result of the activity.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      def complete(
        result = nil,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        raise NotImplementedError
      end

      # Fail the activity.
      #
      # @param error [Exception] Error for the activity.
      # @param last_heartbeat_details [Array<Object>] Last heartbeat details for the activity.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      def fail(
        error,
        last_heartbeat_details: [],
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        raise NotImplementedError
      end

      # Report the activity as cancelled.
      #
      # @param details [Array<Object>] Cancellation details.
      # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param rpc_timeout [Float, nil] Number of seconds before timeout.
      def report_cancellation(
        *details,
        rpc_metadata: nil,
        rpc_timeout: nil
      )
        raise NotImplementedError
      end
    end
  end
end
