# frozen_string_literal: true

require 'temporalio/activity/context'
require 'temporalio/internal/proto_utils'

module Temporalio
  module Activity
    Info = Data.define(
      :activity_id,
      :activity_type,
      :attempt,
      :current_attempt_scheduled_time,
      :heartbeat_timeout,
      :local?,
      :priority,
      :retry_policy,
      :raw_heartbeat_details,
      :schedule_to_close_timeout,
      :scheduled_time,
      :start_to_close_timeout,
      :started_time,
      :task_queue,
      :task_token,
      :workflow_id,
      :workflow_namespace,
      :workflow_run_id,
      :workflow_type
    )

    # Information about an activity.
    #
    # @!attribute activity_id
    #   @return [String] ID for the activity.
    # @!attribute activity_type
    #   @return [String] Type name for the activity.
    # @!attribute attempt
    #   @return [Integer] Attempt the activity is on.
    # @!attribute current_attempt_scheduled_time
    #   @return [Time] When the current attempt was scheduled.
    # @!attribute heartbeat_timeout
    #   @return [Float, nil] Heartbeat timeout set by the caller.
    # @!attribute local?
    #   @return [Boolean] Whether the activity is a local activity or not.
    # @!attribute priority
    #   @return [Priority] The priority of this activity.
    # @!attribute retry_policy
    #   @return [RetryPolicy, nil] Retry policy for the activity. Note that the server may have set a different policy
    #     than the one provided when scheduling the activity. If the value is None, it means the server didn't send
    #     information about retry policy (e.g. due to old server version), but it may still be defined server-side.
    # @!attribute raw_heartbeat_details
    #   @return [Array<Converter::RawValue>] Raw details from the last heartbeat of the last attempt. Can use
    #     {heartbeat_details} to get lazily-converted values.
    # @!attribute schedule_to_close_timeout
    #   @return [Float, nil] Schedule to close timeout set by the caller.
    # @!attribute scheduled_time
    #   @return [Time] When the activity was scheduled.
    # @!attribute start_to_close_timeout
    #   @return [Float, nil] Start to close timeout set by the caller.
    # @!attribute started_time
    #   @return [Time] When the activity started.
    # @!attribute task_queue
    #   @return [String] Task queue this activity is on.
    # @!attribute task_token
    #   @return [String] Task token uniquely identifying this activity. Note, this is a `ASCII-8BIT` encoded string, not
    #     a `UTF-8` encoded string nor a valid UTF-8 string.
    # @!attribute workflow_id
    #   @return [String] Workflow ID that started this activity.
    # @!attribute workflow_namespace
    #   @return [String] Namespace this activity is on.
    # @!attribute workflow_run_id
    #   @return [String] Workflow run ID that started this activity.
    # @!attribute workflow_type
    #   @return [String] Workflow type name that started this activity.
    #
    # @note WARNING: This class may have required parameters added to its constructor. Users should not instantiate this
    #   class or it may break in incompatible ways.
    class Info
      # Convert raw heartbeat details into Ruby types.
      #
      # Note, this live-converts every invocation.
      #
      # @param hints [Array<Object>, nil] Hints, if any, to assist conversion.
      # @return [Array<Object>] Converted details.
      def heartbeat_details(hints: nil)
        Internal::ProtoUtils.convert_from_payload_array(
          Context.current.payload_converter,
          raw_heartbeat_details.map(&:payload),
          hints:
        )
      end
    end
  end
end
