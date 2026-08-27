# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/activity_execution'
require 'temporalio/client/activity_execution_options'
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
      UPDATABLE_OPTION_PATHS = {
        task_queue: 'task_queue.name',
        schedule_to_close_timeout: 'schedule_to_close_timeout',
        schedule_to_start_timeout: 'schedule_to_start_timeout',
        start_to_close_timeout: 'start_to_close_timeout',
        heartbeat_timeout: 'heartbeat_timeout',
        retry_policy: 'retry_policy',
        priority: 'priority',
        start_delay: 'start_delay'
      }.freeze

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
      # The payload-bearing fields are opt-in because they can be arbitrarily large; request them
      # only when needed. Each has a corresponding predicate on the returned description that
      # reports whether the server supplied it.
      #
      # @param include_input [Boolean] If true and the activity received input, include the input.
      # @param include_outcome [Boolean] If true and the activity is closed, include the outcome.
      # @param include_heartbeat_details [Boolean] If true and the activity recorded heartbeat
      #   details, include them.
      # @param include_last_failure [Boolean] If true and the activity has a failed attempt, include
      #   the last failure.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @return [ActivityExecution::Description] Activity description.
      # @raise [Error::RPCError] RPC error from call.
      def describe(
        include_input: false,
        include_outcome: false,
        include_heartbeat_details: false,
        include_last_failure: false,
        rpc_options: nil
      )
        @client._impl.describe_activity(
          Interceptor::DescribeActivityInput.new(
            activity_id: id,
            activity_run_id: run_id,
            include_input:,
            include_outcome:,
            include_heartbeat_details:,
            include_last_failure:,
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
      # @param jitter [Float, nil] If set, the activity will start at a random time within this
      #   duration (in seconds).
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def unpause(reason: nil, jitter: nil, rpc_options: nil)
        @client._impl.unpause_activity(
          Interceptor::UnpauseActivityInput.new(
            activity_id: id,
            activity_run_id: run_id,
            reason:,
            jitter:,
            rpc_options:
          )
        )
        nil
      end

      # Reset the activity. Resetting sets the attempt count back to the start, resets the activity's
      # timeouts, and clears any recorded heartbeat details.
      #
      # WARNING: Standalone Activities are experimental.
      #
      # @param keep_paused [Boolean] If true and the activity is paused, it remains paused after reset.
      # @param jitter [Float, nil] If set and the activity is in backoff, it will start at a random
      #   time within this duration (in seconds).
      # @param restore_original_options [Boolean] If true, restore the activity options to the
      #   originals it was created with.
      # @param reset_heartbeat [Boolean] If true, additionally discard any persisted heartbeat details.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @raise [Error::RPCError] RPC error from call.
      def reset(keep_paused: false, jitter: nil, restore_original_options: false,
                reset_heartbeat: false, rpc_options: nil)
        @client._impl.reset_activity(
          Interceptor::ResetActivityInput.new(
            activity_id: id,
            activity_run_id: run_id,
            keep_paused:,
            jitter:,
            restore_original_options:,
            reset_heartbeat:,
            rpc_options:
          )
        )
        nil
      end

      # Update the activity's options. Only the options you actually pass are changed; anything you
      # omit is left as-is. Passing an option explicitly as `nil` clears it.
      #
      # WARNING: Standalone Activities are experimental.
      #
      # @param restore_original [Boolean] If true, restore the options to the originals the activity
      #   was created with. Mutually exclusive with any other option.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @param options [Hash{Symbol => Object, nil}] The options to change. Keys must be drawn from
      #   {UPDATABLE_OPTION_PATHS}; anything else raises `ArgumentError`.
      # @option options [String, Symbol, nil] :task_queue New task queue.
      # @option options [Float, nil] :schedule_to_close_timeout New schedule-to-close timeout in seconds.
      # @option options [Float, nil] :schedule_to_start_timeout New schedule-to-start timeout in seconds.
      # @option options [Float, nil] :start_to_close_timeout New start-to-close timeout in seconds.
      # @option options [Float, nil] :heartbeat_timeout New heartbeat timeout in seconds.
      # @option options [RetryPolicy, nil] :retry_policy New retry policy.
      # @option options [Priority, nil] :priority New priority.
      # @option options [Float, nil] :start_delay New start delay in seconds.
      #
      # @return [ActivityExecutionOptions] The activity options after the update.
      #
      # @raise [ArgumentError] If an unknown option is given, if `restore_original` is combined with
      #   any other option, or if no option is provided and `restore_original` is false.
      # @raise [Error::RPCError] RPC error from call.
      def update_options(restore_original: false, rpc_options: nil, **options)
        unknown = options.keys - UPDATABLE_OPTION_PATHS.keys
        unless unknown.empty?
          raise ArgumentError,
                "Unknown option(s): #{unknown.join(', ')}. " \
                "Expected any of: #{UPDATABLE_OPTION_PATHS.keys.join(', ')}"
        end

        if restore_original && !options.empty?
          raise ArgumentError, 'restore_original cannot be combined with any other option'
        elsif !restore_original && options.empty?
          raise ArgumentError, 'At least one option must be set, or restore_original must be used'
        end

        proto = Api::Activity::V1::ActivityOptions.new
        if options.key?(:task_queue) && (task_queue = options[:task_queue])
          proto.task_queue = Api::TaskQueue::V1::TaskQueue.new(name: task_queue.to_s)
        end
        %i[schedule_to_close_timeout schedule_to_start_timeout start_to_close_timeout
           heartbeat_timeout start_delay].each do |name|
          next unless options.key?(name)

          value = options[name]
          next if value.nil?

          proto[name.to_s] = Internal::ProtoUtils.seconds_to_duration(value)
        end
        proto.retry_policy = options[:retry_policy]&._to_proto if options.key?(:retry_policy)
        proto.priority = options[:priority]&._to_proto if options.key?(:priority)

        @client._impl.update_activity_options(
          Interceptor::UpdateActivityOptionsInput.new(
            activity_id: id,
            activity_run_id: run_id,
            activity_options: proto,
            update_mask: Google::Protobuf::FieldMask.new(
              paths: options.keys.map { |k| UPDATABLE_OPTION_PATHS.fetch(k) }
            ),
            restore_original:,
            rpc_options:
          )
        )
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
