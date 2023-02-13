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

      def self.all(*futures)
        Future.new do |future, resolve, _reject|
          future.on_cancel { futures.each(&:cancel) }

          futures.each do |f|
            f.then do
              # Resolve the aggregate once all futures have been fulfilled (resolved or rejected)
              resolve.call(nil) if futures.none?(&:pending?)
            end
          end
        end
      end

      def self.any(*futures)
        # This future is never rejected
        Future.new do |future, resolve, _reject|
          future.on_cancel { futures.each(&:cancel) }

          futures.each do |f|
            # Resolve the aggregate once the first future fulfills (resolved or rejected)
            # NOTE: The the first completed future will be the resolved value and all subsequent
            #       calls to `resolve` will have no effect.
            f.then { resolve.call(f) }
          end
        end
      end
    end
  end
end
