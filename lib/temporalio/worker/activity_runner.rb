require 'google/protobuf/well_known_types'
require 'temporalio/activity/context'
require 'temporalio/activity/info'
require 'temporalio/error/failure'
require 'temporalio/errors'
require 'temporalio/interceptor/activity_inbound'

module Temporalio
  class Worker
    # The main class for handling activity processing. It is expected to be executed from
    # some threaded or async executor's context since methods called here might be blocking
    # and this should not affect the main worker reactor.
    #
    # @api private
    class ActivityRunner
      def initialize(
        activity_class,
        start,
        task_queue,
        task_token,
        worker,
        converter,
        inbound_interceptors,
        outbound_interceptors
      )
        @activity_class = activity_class
        @start = start
        @task_queue = task_queue
        @task_token = task_token
        @worker = worker
        @converter = converter
        @inbound_interceptors = inbound_interceptors
        @outbound_interceptors = outbound_interceptors
      end

      def run
        activity = activity_class.new(context)
        args = converter.from_payload_array(start.input.to_a)
        headers = converter.from_payload_map(start.header_fields)
        input = Temporalio::Interceptor::ActivityInbound::ExecuteActivityInput.new(
          activity: activity_class,
          args: args,
          headers: headers || {},
        )

        result = inbound_interceptors.invoke(:execute_activity, input) do |i|
          activity.execute(*i.args)
        end

        converter.to_payload(result)
      rescue StandardError => e
        # Temporal server ignores cancellation failures that were not requested by the server.
        # However within the SDK cancellations are also used during the worker shutdown. In order
        # to provide a seamless handling experience (same error raised within the Activity) we are
        # using the ActivityCancelled error and then swapping it with a CancelledError here.
        #
        # In the future this will be handled by the SDK Core — https://github.com/temporalio/sdk-core/issues/461
        if e.is_a?(Temporalio::Error::ActivityCancelled) && e.by_request?
          e = Temporalio::Error::CancelledError.new(e.message)
        end

        converter.to_failure(e)
      end

      def cancel(reason, by_request:)
        context.cancel(reason, by_request: by_request)
      end

      private

      attr_reader :activity_class, :start, :task_queue, :task_token, :worker, :converter,
                  :inbound_interceptors, :outbound_interceptors

      def context
        return @context if @context

        heartbeat_proc = ->(*details) { heartbeat(*details) }
        @context = Temporalio::Activity::Context.new(
          generate_activity_info,
          heartbeat_proc,
          outbound_interceptors,
          shielded: activity_class._shielded,
        )
      end

      def generate_activity_info
        Temporalio::Activity::Info.new(
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

      def heartbeat(*details)
        payloads = converter.to_payload_array(details)
        worker.record_activity_heartbeat(task_token, payloads)
      end
    end
  end
end
