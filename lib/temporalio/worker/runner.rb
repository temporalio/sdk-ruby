module Temporalio
  class Worker
    class Runner
      def initialize(*workers)
        if workers.empty?
          raise ArgumentError, 'Must be initialized with at least one worker'
        end

        @workers = workers
        @mutex = Mutex.new
        @started = false
        @shutdown = false
      end

      def run(&block)
        @thread = Thread.current
        @started = true
        workers.each { |worker| worker.start(self) }

        block ? block.call : sleep
      rescue Temporalio::Error::WorkerShutdown
        # Explicit shutdown requested, no need to raise
      ensure
        @shutdown = true
        shutdown_workers
      end

      def shutdown(exception = Temporalio::Error::WorkerShutdown.new('Manual shutdown'))
        mutex.synchronize do
          return unless running?

          @shutdown = true
        end

        # propagate shutdown to the running thread
        thread&.raise(exception)
      end

      private

      attr_reader :workers, :mutex, :thread

      def running?
        @started && !@shutdown
      end

      def shutdown_workers
        # Protect shutdown from any outside raises
        Thread.handle_interrupt(StandardError => :never) do
          workers.map do |worker|
            # Shut down each worker (and wait for it) concurrently in separate threads
            Thread.new { worker.shutdown }
          end.each(&:join)
        end
      end
    end
  end
end
