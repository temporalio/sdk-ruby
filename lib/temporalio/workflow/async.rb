require 'temporalio/workflow/future'

module Temporalio
  class Workflow
    module Async
      def self.run(&block)
        Future.new do |future, resolve, reject|
          Fiber.new do
            Future.current = future
            result = block.call
            resolve.call(result)
          rescue StandardError => e
            reject.call(e)
          end.resume
        end
      end

      # TODO: Figure out cancellation for combined futures
      def self.all(*futures)
        Future.new do |_future, resolve, _reject|
          futures.each do |future|
            future.then do
              # Resolve the aggregate once all futures have been fulfilled
              resolve.call(nil) if futures.none?(&:pending?)
            end
          end
        end
      end

      def self.any(*futures)
        Future.new do |_future, resolve, _reject|
          futures.each do |future|
            # Resolve the aggregate once the first future fulfills
            # All subsequent calls to `resolve` will have no effect
            future.then { resolve.call(nil) }
          end
        end
      end
    end
  end
end
