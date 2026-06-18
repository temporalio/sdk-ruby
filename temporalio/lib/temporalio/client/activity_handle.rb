# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/activity_execution'
require 'temporalio/client/interceptor'
require 'temporalio/error'
require 'temporalio/internal/proto_utils'
require 'temporalio/priority'
require 'temporalio/retry_policy'

module Temporalio
  class Client
    # Handle for interacting with a standalone activity. Usually created via {Client.activity_handle}
    # or {Client#start_activity}.
    #
    # WARNING: Standalone Activities are experimental.
    class ActivityHandle
      # Sentinel used by {#update_options} to distinguish an option that was not provided from one
      # explicitly set (including set to nil). Only provided options are included in the update mask.
      UNSET = Object.new
      private_constant :UNSET

      # Read-only view of a standalone activity's options, returned by {ActivityHandle#update_options}.
      #
      # WARNING: Standalone Activities are experimental.
      UpdatedOptions = Data.define(
        :task_queue,
        :schedule_to_close_timeout,
        :schedule_to_start_timeout,
        :start_to_close_timeout,
        :heartbeat_timeout,
        :retry_policy,
        :priority
      ) do
        # @!visibility private
        def self._from_proto(options)
          new(
            task_queue: Internal::ProtoUtils.string_or(options.task_queue&.name, nil),
            schedule_to_close_timeout: Internal::ProtoUtils.duration_to_seconds(options.schedule_to_close_timeout),
            schedule_to_start_timeout: Internal::ProtoUtils.duration_to_seconds(options.schedule_to_start_timeout),
            start_to_close_timeout: Internal::ProtoUtils.duration_to_seconds(options.start_to_close_timeout),
            heartbeat_timeout: Internal::ProtoUtils.duration_to_seconds(options.heartbeat_timeout),
            retry_policy: options.retry_policy ? RetryPolicy._from_proto(options.retry_policy) : nil,
            priority: Priority._from_proto(options.priority)
          )
        end
      end
      # @return [String] ID for the activity.
      attr_reader :id

      # @return [String, nil] Run ID for this activity execution. When nil, this handle targets the latest run.
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

      # Wait for the activity's outcome (result or failure). Internally long-polls
      # PollActivityExecution and reissues until the activity reaches a terminal state, so this can
      # block indefinitely for long-running activities.
      #
      # @param result_hint [Object, nil] Override the result hint. If nil, uses {#result_hint}.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @return [Object, nil] Deserialized activity result.
      #
      # @raise [Error::ActivityFailedError] With `cause` populated from the activity failure.
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

      # Describe the activity.
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

      # Pause the activity. A paused activity is not scheduled or retried until it is unpaused via
      # {#unpause}.
      #
      # WARNING: Standalone Activities are experimental.
      #
      # @param reason [String, nil] Optional reason recorded on the server.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def pause(reason = nil, rpc_options: nil)
        @client._impl.pause_activity(
          Interceptor::PauseActivityInput.new(
            activity_id: id,
            activity_run_id: run_id,
            reason:,
            rpc_options:
          )
        )
        nil
      end

      # Unpause the activity, allowing it to be scheduled or retried again.
      #
      # WARNING: Standalone Activities are experimental.
      #
      # @param reason [String, nil] Optional reason recorded on the server.
      # @param reset_attempts [Boolean] If true, also reset the activity's attempt count.
      # @param reset_heartbeat [Boolean] If true, also reset the activity's heartbeat details.
      # @param jitter [Float, nil] If set, the activity will start at a random time within this
      #   duration (in seconds).
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def unpause(reason: nil, reset_attempts: false, reset_heartbeat: false, jitter: nil, rpc_options: nil)
        @client._impl.unpause_activity(
          Interceptor::UnpauseActivityInput.new(
            activity_id: id,
            activity_run_id: run_id,
            reason:,
            reset_attempts:,
            reset_heartbeat:,
            jitter:,
            rpc_options:
          )
        )
        nil
      end

      # Reset the activity. Resetting sets the attempt count back to the start and resets the
      # activity's timeouts.
      #
      # WARNING: Standalone Activities are experimental.
      #
      # @param reset_heartbeat [Boolean] If true, reset the activity's heartbeat details.
      # @param keep_paused [Boolean] If true and the activity is paused, it remains paused after reset.
      # @param jitter [Float, nil] If set and the activity is in backoff, it will start at a random
      #   time within this duration (in seconds).
      # @param restore_original_options [Boolean] If true, restore the activity options to the
      #   originals it was created with.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def reset(reset_heartbeat: false, keep_paused: false, jitter: nil, restore_original_options: false,
                rpc_options: nil)
        @client._impl.reset_activity(
          Interceptor::ResetActivityInput.new(
            activity_id: id,
            activity_run_id: run_id,
            reset_heartbeat:,
            keep_paused:,
            jitter:,
            restore_original_options:,
            rpc_options:
          )
        )
        nil
      end

      # Update the activity's options. Only the options explicitly provided are changed; any option
      # left as its default is not included in the update.
      #
      # WARNING: Standalone Activities are experimental.
      #
      # @param task_queue [String, nil] New task queue.
      # @param schedule_to_close_timeout [Float, nil] New schedule-to-close timeout in seconds.
      # @param schedule_to_start_timeout [Float, nil] New schedule-to-start timeout in seconds.
      # @param start_to_close_timeout [Float, nil] New start-to-close timeout in seconds.
      # @param heartbeat_timeout [Float, nil] New heartbeat timeout in seconds.
      # @param retry_policy [RetryPolicy, nil] New retry policy.
      # @param priority [Priority, nil] New priority.
      # @param restore_original [Boolean] If true, restore the options to the originals the activity
      #   was created with. Mutually exclusive with any other option.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @return [UpdatedOptions] The activity options after the update.
      #
      # @raise [ArgumentError] If `restore_original` is combined with any other option.
      # @raise [Error::RPCError] RPC error from call.
      def update_options(
        task_queue: UNSET,
        schedule_to_close_timeout: UNSET,
        schedule_to_start_timeout: UNSET,
        start_to_close_timeout: UNSET,
        heartbeat_timeout: UNSET,
        retry_policy: UNSET,
        priority: UNSET,
        restore_original: false,
        rpc_options: nil
      )
        options = Api::Activity::V1::ActivityOptions.new
        paths = []

        unless UNSET.equal?(task_queue)
          paths << 'task_queue'
          options.task_queue = Api::TaskQueue::V1::TaskQueue.new(name: task_queue.to_s) if task_queue
        end
        unless UNSET.equal?(schedule_to_close_timeout)
          paths << 'schedule_to_close_timeout'
          options.schedule_to_close_timeout = Internal::ProtoUtils.seconds_to_duration(schedule_to_close_timeout)
        end
        unless UNSET.equal?(schedule_to_start_timeout)
          paths << 'schedule_to_start_timeout'
          options.schedule_to_start_timeout = Internal::ProtoUtils.seconds_to_duration(schedule_to_start_timeout)
        end
        unless UNSET.equal?(start_to_close_timeout)
          paths << 'start_to_close_timeout'
          options.start_to_close_timeout = Internal::ProtoUtils.seconds_to_duration(start_to_close_timeout)
        end
        unless UNSET.equal?(heartbeat_timeout)
          paths << 'heartbeat_timeout'
          options.heartbeat_timeout = Internal::ProtoUtils.seconds_to_duration(heartbeat_timeout)
        end
        unless UNSET.equal?(retry_policy)
          paths << 'retry_policy'
          options.retry_policy = retry_policy&._to_proto
        end
        unless UNSET.equal?(priority)
          paths << 'priority'
          options.priority = priority&._to_proto
        end

        if restore_original && !paths.empty?
          raise ArgumentError, 'restore_original cannot be combined with any other option'
        end

        result = @client._impl.update_activity_options(
          Interceptor::UpdateActivityOptionsInput.new(
            activity_id: id,
            activity_run_id: run_id,
            activity_options: options,
            update_mask: Google::Protobuf::FieldMask.new(paths:),
            restore_original:,
            rpc_options:
          )
        )
        UpdatedOptions._from_proto(result)
      end

      private

      def _process_outcome(outcome, hint)
        raise Error, 'Activity completed but outcome is missing from server response' if outcome.nil?

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
