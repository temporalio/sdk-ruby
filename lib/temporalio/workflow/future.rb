module Temporalio
  class Workflow
    class Future
      class Rejected < StandardError; end

      def self.current
        Thread.current[:future]
      end

      def self.current=(future)
        Thread.current[:future] = future
      end

      # Revist the reason for combining futures and cancellation scopes, maybe they are separate?
      def initialize(&block)
        @resolved = false
        @value = nil
        @rejected = false
        @error = Rejected.new('Future rejected')
        @cancel_requested = false
        @blocked_fibers = []
        @callbacks = []
        @cancel_callbacks = []

        # Chain cancellation into parent future if one exists
        Future.current&.on_cancel { cancel }

        # NOTE: resolve and reject methods are accessible via procs to avoid exposing
        #       them via the public interface.
        block.call(
          self,
          ->(value) { resolve(value) },
          ->(error) { reject(error) },
        )
      end

      def then(&block)
        Future.new do |future, resolve, reject|
          # @type var wrapped_block: ^() -> void
          wrapped_block = -> do # rubocop:disable Style/Lambda
            Fiber.new do
              Future.current = future
              # The block is provided the Future on which #then was called
              result = block.call(self)
              resolve.call(result)
            rescue StandardError => e
              reject.call(e)
            end.resume
          end

          if pending?
            callbacks << wrapped_block
          else
            wrapped_block.call
          end
        end
      end

      def on_cancel(&block)
        if pending? && !cancel_requested?
          cancel_callbacks << block
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

      def cancel
        return unless pending?

        @cancel_requested = true
        cancel_callbacks.each(&:call)
      end

      private

      attr_reader :value, :error, :blocked_fibers, :callbacks, :cancel_callbacks

      def cancel_requested?
        @cancel_requested
      end

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
