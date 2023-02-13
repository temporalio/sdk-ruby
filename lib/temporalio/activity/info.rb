module Temporalio
  class Activity
    # Class containing information about an activity.
    class Info < Struct.new(
      :activity_id,
      :activity_type,
      :attempt,
      :current_attempt_scheduled_time,
      :heartbeat_details,
      :heartbeat_timeout,
      :local,
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
      keyword_init: true,
    )
      # @!attribute [r] activity_id
      #   @return [String] Activity ID.
      # @!attribute [r] activity_type
      #   @return [String] Name of the activity.
      # @!attribute [r] attempt
      #   @return [Integer] Activity's execution attempt.
      # @!attribute [r] current_attempt_scheduled_time
      #   @return [Time] Scheduled time of the current attempt.
      # @!attribute [r] heartbeat_details
      #   @return [Array<any>] Details submitted with the last heartbeat.
      # @!attribute [r] heartbeat_timeout
      #   @return [Float] Max time between heartbeats (in seconds).
      # @!attribute [r] local
      #   @return [Boolean] Whether activity is local or not.
      # @!attribute [r] schedule_to_close_timeout
      #   @return [Float] Max overall activity execution time (in seconds).
      # @!attribute [r] scheduled_time
      #   @return [Time] Time when activity was first scheduled.
      # @!attribute [r] start_to_close_timeout
      #   @return [Float] Max time of a single invocation (in seconds).
      # @!attribute [r] started_time
      #   @return [Time] Time when activity was started.
      # @!attribute [r] task_queue
      #   @return [String] Task queue on which the activity got scheduled.
      # @!attribute [r] task_token
      #   @return [String] A token for completing the activity.
      # @!attribute [r] workflow_id
      #   @return [String] Workflow ID.
      # @!attribute [r] workflow_namespace
      #   @return [String] Workflow namespace.
      # @!attribute [r] workflow_run_id
      #   @return [String] Workflow run ID.
      # @!attribute [r] workflow_type
      #   @return [String] Name of the workflow.

      # Whether activity is local or not
      #
      # @return [Boolean] True for local activities, falst otherwise.
      def local?
        local
      end
    end
  end
end
