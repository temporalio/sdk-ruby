module Temporalio
  class Worker
    # A generic fixed thread pool.
    #
    # This is used to execute multiple activities concurrently and independenty of each other.
    #
    # @note This is a fixed thread pool that allocated threads eagerly and has an infinite buffer.
    class ThreadPoolExecutor
      # Generate new thread pool executor.
      #
      # @param size [Integer] Number of concurrently executing threads.
      def initialize(size)
        @queue = Queue.new
        @pool = Array.new(size) do
          Thread.new { poll }
        end
      end

      # Execute a block of code inside of the threads.
      #
      # @yield Block of code to be executed.
      def schedule(&block)
        queue << block
      end

      # Stop the thread pool and wait for all threads to finish work.
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
