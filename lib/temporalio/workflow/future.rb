module Temporalio
  class Workflow
    class Future
      class Rejected < StandardError; end

      # Revist the reason for combining futures and cancellation scopes, maybe they are separate?
      def initialize(&block)
        @resolved = false
        @value = nil
        @rejected = false
        @error = Rejected.new('Future rejected')
        @blocked_fibers = []
        @callbacks = []

        # NOTE: resolve and reject methods are accessible via procs to avoid exposing
        #       them via the public interface.
        block.call(
          ->(value) { resolve(value) },
          ->(error) { reject(error) },
        )
      end

      def then(&block)
        if pending?
          callbacks << block
        else
          block.call
        end
      end

      def pending?
        !resolved? && !rejected?
      end

      def resolved?
        @resolved
      end

      def rejected?
        @rejected
      end

      def await
        if pending?
          blocked_fibers << Fiber.current
          # yield into the parent fiber
          Fiber.yield while pending?
        end

        raise error if rejected?

        value
      end

      private

      attr_reader :value, :error, :blocked_fibers, :callbacks

      # TODO: Run callbacks in a Fiber to allow blocking calls
      def run_callbacks
        callbacks.each(&:call)
      end

      # Unblock every fiber that this future is awaited on
      def resume_fibers
        blocked_fibers.each(&:resume)
      end

      def resolve(value)
        return unless pending?

        @value = value
        @resolved = true
        run_callbacks
        resume_fibers
      end

      def reject(error)
        return unless pending?

        @error = error
        @rejected = true
        run_callbacks
        resume_fibers
      end
    end
  end
end
