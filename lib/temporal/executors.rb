require 'async'

module Temporal
  class Executors
    class FakePool
      def initialize(**); end

      def post(&block)
        block.call
      end

      def shutdown; end
    end

    attr_reader :pool

    # TODO: Thread pool impl.
    def initialize(pool: FakePool.new)
      @pool = pool
    end

    def terminate
      pool.shutdown
    end

    # TODO: Handle task execution strategies
    #
    def execute(task)
      pool.post do
        task.executed = true
      end
    end
  end
end
