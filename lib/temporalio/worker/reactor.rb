require 'async'

module Temporalio
  class Worker
    # A shared async reactor.
    #
    # This class allows multiple workers to access the same Async reactor
    # without forcing the SDK users to wrap their execution in an Async block. This
    # is handled using a queue that is polled from within a running Async reactor,
    # so all the blocks end up being executed within it.
    #
    # @api private
    class Reactor
      def initialize
        @queue = Queue.new
        @thread = nil
        @mutex = Mutex.new
      end

      def async(&block)
        ensure_reactor_thread
        queue << block
      end

      private

      attr_reader :queue, :mutex

      def ensure_reactor_thread
        mutex.synchronize do
          @thread ||= Thread.new { run_loop }
        end
      end

      def run_loop
        reactor = Async::Reactor.new
        reactor.run do |task|
          loop do
            block = queue.pop
            task.async { |subtask| block.call(subtask) }
          end
        end
      end
    end
  end
end
