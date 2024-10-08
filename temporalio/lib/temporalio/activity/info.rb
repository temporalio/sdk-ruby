# frozen_string_literal: true

module Temporalio
  class Activity
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
    # @!attribute heartbeat_details
    #   @return [Array<Object>] Details from the last heartbeat of the last attempt.
    # @!attribute heartbeat_timeout
    #   @return [Float, nil] Heartbeat timeout set by the caller.
    # @!attribute local?
    #   @return [Boolean] Whether the activity is a local activity or not.
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
    Info = Struct.new(
      :activity_id,
      :activity_type,
      :attempt,
      :current_attempt_scheduled_time,
      :heartbeat_details,
      :heartbeat_timeout,
      :local?,
      :schedule_to_close_timeout,
      :scheduled_time,
      :start_to_close_timeout,
      :started_time,
      :task_queue,
      :task_token,
      :workflow_id,
      :workflow_namespace,
      :workflow_run_id,
      :workflow_type,
      keyword_init: true
    )
  end
end
