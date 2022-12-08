require 'temporal/error/failure'

module Temporal
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

        mutex.synchronize do
          @shielded = true
          result = block.call
          raise Temporal::Error::CancelledError, 'Unhandled cancellation' if @cancelled

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

        # @shielded inside the lock means the whole activity is shielded
        if mutex.try_lock && !@shielded
          thread.raise(Temporal::Error::CancelledError.new('Unhandled cancellation'))
        end
      ensure
        # only release the lock if owned by the current thread
        mutex.unlock if mutex.owned?
      end

      private

      attr_reader :thread, :heartbeat_proc, :mutex
    end
  end
end
