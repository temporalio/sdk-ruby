module Temporal
  class Activity
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
      def local?
        local
      end
    end
  end
end
