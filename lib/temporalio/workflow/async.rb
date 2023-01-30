require 'temporalio/workflow/future'

module Temporalio
  class Workflow
    module Async
      def self.run(&block)
        Future.new do |resolve, reject|
          Fiber.new do
            block.call
            resolve.call
          rescue StandardError
            reject.call
          end.resume
        end
      end

      def self.all(*futures)
        Future.new do |resolve, _reject|
          futures.each do |future|
            future.then do
              # Resolve the aggregate once all futures have been fulfilled
              resolve.call if futures.none?(&:pending?)
            end
          end
        end
      end

      def self.any(*futures)
        Future.new do |resolve, _reject|
          futures.each do |future|
            # Resolve the aggregate once the first future fulfills
            # All subsequent calls to `resolve` will have no effect
            future.then { resolve.call }
          end
        end
      end
    end
  end
end
