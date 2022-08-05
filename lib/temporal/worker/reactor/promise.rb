module Temporal
  class Worker
    class Reactor
      class Promise
        class AlreadyFulfilledError < StandardError; end

        def initialize
          @result = nil
          @fulfilled = false
        end

        def fulfilled?
          @fulfilled
        end

        def result
          wait

          raise @exception if defined?(@exception)

          @result
        end

        def wait
          return if fulfilled?

          @fiber = Fiber.current

          Fiber.yield
        end

        def set(value)
          raise AlreadyFulfilledError if fulfilled?

          if value.is_a?(Exception)
            @exception = value
          else
            @result = value
          end

          @fulfilled = true

          resume_fiber
        end

        private

        attr_reader :mutex

        def resume_fiber
          @fiber&.resume
          @fiber = nil
        end
      end
    end
  end
end
