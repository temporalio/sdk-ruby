# frozen_string_literal: true

require 'temporalio/error'

module Temporalio
  module Activity
    # Details that are set when an activity is cancelled. This is only valid at the time the cancel was received, the
    # state may change on the server after it is received.
    class CancellationDetails
      def initialize(
        gone_from_server: false,
        cancel_requested: true,
        timed_out: false,
        worker_shutdown: false,
        paused: false,
        reset: false
      )
        @gone_from_server = gone_from_server
        @cancel_requested = cancel_requested
        @timed_out = timed_out
        @worker_shutdown = worker_shutdown
        @paused = paused
        @reset = reset
      end

      # @return [Boolean] Whether the activity no longer exists on the server (may already be completed or its workflow
      #   may be completed).
      def gone_from_server?
        @gone_from_server
      end

      # @return [Boolean] Whether the activity was explicitly cancelled.
      def cancel_requested?
        @cancel_requested
      end

      # @return [Boolean] Whether the activity timeout caused activity to be marked cancelled.
      def timed_out?
        @timed_out
      end

      # @return [Boolean] Whether the worker the activity is running on is shutting down.
      def worker_shutdown?
        @worker_shutdown
      end

      # @return [Boolean] Whether the activity was explicitly paused.
      def paused?
        @paused
      end

      # @return [Boolean] Whether the activity was explicitly reset.
      def reset?
        @reset
      end
    end
  end
end
