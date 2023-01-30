module Temporalio
  class Workflow
    class Future
      # Revist the reason for combining futures and cancellation scopes, maybe they are separate?
      def initialize(&block)
        @resolved = false
        @rejected = false
        @blocked_fibers = []
        @callbacks = []

        # NOTE: resolve and reject methods are accessible via procs to avoid exposing
        #       them via the public interface.
        block.call(-> { resolve }, -> { reject })
      end

      def then(&block)
        if pending?
          callbacks << block
        else
          block.call
        end
      end

      def pending?
        !@resolved && !@rejected
      end

      # TODO: This should probably return resolved value or raise
      def await
        return unless pending?

        blocked_fibers << Fiber.current
        # yield into the parent fiber
        Fiber.yield while pending?
      end

      private

      attr_reader :blocked_fibers, :callbacks

      # TODO: Run callbacks in a Fiber to allow blocking calls
      def run_callbacks
        callbacks.each(&:call)
      end

      # Unblock every fiber that this future is awaited on
      def resume_fibers
        blocked_fibers.each(&:resume)
      end

      def resolve
        return unless pending?

        @resolved = true
        run_callbacks
        resume_fibers
      end

      def reject
        return unless pending?

        @rejected = true
        run_callbacks
        resume_fibers
      end
    end
  end
end
