module Temporal
  class Worker
    # The main class for handling activity processing. It is expected to be executed from
    # some threaded or async executor's context since methods called here might be blocking
    # and this should not affect the main worker reactor.
    class ActivityTaskProcessor
      def initialize(task)
        @task = task
      end

      def process
        puts "Processing activity ##{task.activity_id} for #{task.workflow_execution&.run_id}"
        # TODO: pending implementation
        "test activity result ##{task.activity_id}"
      end

      private

      attr_reader :task
    end
  end
end
