require 'temporalio/error/failure'

module Temporalio
  class Activity
    class Context
      attr_reader :info

      def initialize(info, heartbeat_proc, shielded: false)
        @thread = Thread.current
        @info = info
        @heartbeat_proc = heartbeat_proc
        @cancelled = false
        @shielded = shielded
        @mutex = Mutex.new
      end

      def heartbeat(*details)
        heartbeat_proc.call(*details)
      end

      def shield(&block)
        # The whole activity is shielded, called from a nested shield
        #   or while handling a CancelledError (in a rescue or ensure blocks)
        return block.call if @shielded || @cancelled

        if Thread.current != thread
          # TODO: Use logger instead when implemented
          warn "Activity shielding is not intended to be used outside of activity's thread."
          return block.call
        end

        mutex.synchronize do
          @shielded = true
          result = block.call
          raise Temporalio::Error::CancelledError, 'Unhandled cancellation' if @cancelled

          result
        ensure # runs while still holding the lock
          @shielded = false
        end
      end

      def cancelled?
        @cancelled
      end

      def cancel
        @cancelled = true

        locked = mutex.try_lock
        # @shielded inside the lock means the whole activity is shielded
        if locked && !@shielded
          thread.raise(Temporalio::Error::CancelledError.new('Unhandled cancellation'))
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
