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

      # TODO: Do we need to reject this if any future is rejected?
      def self.all(*futures)
        Future.new do |future, resolve, _reject|
          future.on_cancel { futures.each(&:cancel) }

          futures.each do |f|
            f.then do
              # Resolve the aggregate once all futures have been fulfilled
              resolve.call(nil) if futures.none?(&:pending?)
            end
          end
        end
      end

      # TODO: Do we need to reject this if any future is rejected?
      def self.any(*futures)
        Future.new do |future, resolve, _reject|
          future.on_cancel { futures.each(&:cancel) }

          futures.each do |f|
            # Resolve the aggregate once the first future fulfills
            # All subsequent calls to `resolve` will have no effect
            f.then { resolve.call(nil) }
          end
        end
      end
    end
  end
end
