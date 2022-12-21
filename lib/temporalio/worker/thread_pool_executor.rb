module Temporalio
  class Worker
    class ThreadPoolExecutor
      def initialize(size)
        @queue = Queue.new
        @pool = Array.new(size) do
          Thread.new { poll }
        end
      end

      def schedule(&block)
        queue << block
      end

      def shutdown
        pool.size.times do
          schedule { throw EXIT_SYMBOL }
        end

        pool.each(&:join)
      end

      private

      attr_reader :queue, :pool

      EXIT_SYMBOL = :exit

      def poll
        catch(EXIT_SYMBOL) do
          loop do
            job = queue.pop
            job.call
          end
        end
      end
    end
  end
end
