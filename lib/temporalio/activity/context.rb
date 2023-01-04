require 'temporalio/error/failure'
require 'temporalio/errors'

module Temporalio
  class Activity
    # This class provides methods that can be called from activity classes.
    class Context
      # Information about the running activity.
      #
      # @return [Temporalio::Activity::Info]
      attr_reader :info

      # @api private
      def initialize(info, heartbeat_proc, shielded: false)
        @thread = Thread.current
        @info = info
        @heartbeat_proc = heartbeat_proc
        @pending_cancellation = nil
        @shielded = shielded
        @mutex = Mutex.new
      end

      # Send a heartbeat for the current activity.
      #
      # @param details [Array<any>] Data to store with the heartbeat.
      def heartbeat(*details)
        heartbeat_proc.call(*details)
      end

      # Protect a part of activity's implementation from cancellations.
      #
      # Activity cancellations are implemented using the `Thread#raise`, which can unsafely
      # terminate your implementation. To disable this behaviour make sure to wrap critical parts of
      # your business logic in this method.
      #
      # For shielding a whole activity consider using {Temporalio::Activity.shielded!}.
      #
      # A cancellation that got requested while in a shielded block will not interrupt the execution
      # and will raise a {Temporalio::Error::CancelledError} right after the block has finished.
      #
      # @yield Block to be protected from cancellations.
      def shield(&block)
        # The whole activity is shielded, called from a nested shield
        #   or while handling a CancelledError (in a rescue or ensure blocks)
        return block.call if @shielded || cancelled?

        if Thread.current != thread
          # TODO: Use logger instead when implemented
          warn "Activity shielding is not intended to be used outside of activity's thread."
          return block.call
        end

        mutex.synchronize do
          @shielded = true
          result = block.call
          # RBS: StandardError fallback is only needed to satisfy steep - https://github.com/soutaro/steep/issues/477
          raise @pending_cancellation || StandardError if cancelled?

          result
        ensure # runs while still holding the lock
          @shielded = false
        end
      end

      # Whether a cancellation was ever requested on this activity.
      #
      # @return [Boolean] true if the activity has had a cancellation request, false otherwise.
      def cancelled?
        !!@pending_cancellation
      end

      # Cancel the running activity by raising a provided error.
      #
      # @param reason [String] Reason for cancellation.
      # @param by_request [Boolean] Cancellation requested by the server or not.
      #
      # @api private
      def cancel(reason, by_request: false)
        error = Temporalio::Error::ActivityCancelled.new(reason, by_request)
        @pending_cancellation = error

        locked = mutex.try_lock
        # @shielded inside the lock means the whole activity is shielded
        if locked && !@shielded
          thread.raise(error)
        end
      ensure
        # only release the lock if we locked it
        mutex.unlock if locked
      end

      private

      attr_reader :thread, :heartbeat_proc, :mutex
    end
  end
end
