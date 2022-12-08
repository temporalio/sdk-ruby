require 'google/protobuf/well_known_types'
require 'temporal/activity/context'
require 'temporal/activity/info'

module Temporal
  class Worker
    # The main class for handling activity processing. It is expected to be executed from
    # some threaded or async executor's context since methods called here might be blocking
    # and this should not affect the main worker reactor.
    class ActivityRunner
      def initialize(activity_class, start, task_queue, task_token, converter)
        @activity_class = activity_class
        @start = start
        @task_queue = task_queue
        @task_token = task_token
        @converter = converter
      end

      def run
        context = Temporal::Activity::Context.new(generate_activity_info)
        activity = activity_class.new(context)
        input = converter.from_payload_array(start.input.to_a)

        result = activity.execute(*input)

        converter.to_payload(result)
      rescue StandardError => e
        converter.to_failure(e)
      end

      def cancel
        # TODO: pending implementation
      end

      private

      attr_reader :activity_class, :start, :task_queue, :task_token, :converter

      def generate_activity_info
        Temporal::Activity::Info.new(
          activity_id: start.activity_id,
          activity_type: start.activity_type,
          attempt: start.attempt,
          current_attempt_scheduled_time: start.current_attempt_scheduled_time&.to_time,
          heartbeat_details: converter.from_payload_array(start.heartbeat_details.to_a),
          heartbeat_timeout: start.heartbeat_timeout&.to_f,
          local: !start.is_local.nil?,
          schedule_to_close_timeout: start.schedule_to_close_timeout&.to_f,
          scheduled_time: start.scheduled_time&.to_time,
          start_to_close_timeout: start.start_to_close_timeout&.to_f,
          started_time: start.started_time&.to_time,
          task_queue: task_queue,
          task_token: task_token,
          workflow_id: start.workflow_execution&.workflow_id,
          workflow_namespace: start.workflow_namespace,
          workflow_run_id: start.workflow_execution&.run_id,
          workflow_type: start.workflow_type,
        ).freeze
      end
    end
  end
end
