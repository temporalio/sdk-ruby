# frozen_string_literal: true

require 'temporalio/error'

module Temporalio
  class Activity
    # Context accessible only within an activity. Use {current} to get the current context. Contexts are fiber or thread
    # local so may not be available in a newly started thread from an activity and may have to be propagated manually.
    class Context
      # @return [Context] The current context, or raises an error if not in activity fiber/thread.
      def self.current
        context = current_or_nil
        raise Error, 'Not in activity context' if context.nil?

        context
      end

      # @return [Context, nil] The current context or nil if not in activity fiber/thread.
      def self.current_or_nil
        _current_executor&.activity_context
      end

      # @return [Boolean] Whether there is a current context available.
      def self.exist?
        !current_or_nil.nil?
      end

      # @!visibility private
      def self._current_executor
        if Fiber.current_scheduler
          Fiber[:temporal_activity_executor]
        else
          Thread.current[:temporal_activity_executor]
        end
      end

      # @!visibility private
      def self._current_executor=(executor)
        if Fiber.current_scheduler
          Fiber[:temporal_activity_executor] = executor
        else
          Thread.current[:temporal_activity_executor] = executor
        end
      end

      # @return [Info] Activity info for this activity.
      def info
        raise NotImplementedError
      end

      # Record a heartbeat on the activity.
      #
      # Heartbeats should be used for all non-immediately-returning, non-local activities and they are required to
      # receive cancellation. Heartbeat calls are throttled internally based on the heartbeat timeout of the activity.
      # Users do not have to be concerned with burdening the server by calling this too frequently.
      #
      # @param details [Array<Object>] Details to record with the heartbeat.
      def heartbeat(*details)
        raise NotImplementedError
      end

      # @return [Cancellation] Cancellation that is canceled when the activity is canceled.
      def cancellation
        raise NotImplementedError
      end

      # @return [Cancellation] Cancellation that is canceled when the worker is shutting down. On worker shutdown, this
      #   is canceled, then the `graceful_shutdown_period` is waited (default 0s), then the activity is canceled.
      def worker_shutdown_cancellation
        raise NotImplementedError
      end

      # @return [Converters::PayloadConverter] Payload converter associated with this activity.
      def payload_converter
        raise NotImplementedError
      end

      # @return [ScopedLogger] Logger for this activity. Note, this is a shared logger not created each activity
      #   invocation. It just has logic to extract current activity details and so is only able to do so on log calls
      #   made with a current context available.
      def logger
        raise NotImplementedError
      end

      # @return [Definition] Definition for this activity.
      def definition
        raise NotImplementedError
      end

      # @!visibility private
      def _scoped_logger_info
        return @scoped_logger_info unless @scoped_logger_info.nil?

        curr_info = info
        @scoped_logger_info = {
          temporal_activity: {
            activity_id: curr_info.activity_id,
            activity_type: curr_info.activity_type,
            attempt: curr_info.attempt,
            task_queue: curr_info.task_queue,
            workflow_id: curr_info.workflow_id,
            workflow_namespace: curr_info.workflow_namespace,
            workflow_run_id: curr_info.workflow_run_id,
            workflow_type: curr_info.workflow_type
          }
        }.freeze
      end

      # TODO(cretz): metric meter
    end
  end
end
