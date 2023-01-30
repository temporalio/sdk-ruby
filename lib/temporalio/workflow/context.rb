require 'temporalio/workflow/async'
require 'temporalio/workflow/future'

module Temporalio
  class Workflow
    class Context
      def initialize(runner)
        @runner = runner
      end

      def async(&block)
        if block
          Temporalio::Workflow::Async.run(&block)
        else
          Temporalio::Workflow::Async
        end
      end

      def sleep(duration)
        timer = start_timer(duration)
        timer.await
      end

      def start_timer(duration)
        Future.new do |resolve, reject|
          seq = runner.add_completion(:timer, resolve, reject)

          # TODO: Do we need our own struct interface for commands?
          runner.push_command(
            Coresdk::WorkflowCommands::WorkflowCommand.new(
              start_timer: Coresdk::WorkflowCommands::StartTimer.new(
                seq: seq,
                start_to_fire_timeout: Google::Protobuf::Duration.new(seconds: duration),
              ),
            ),
          )
        end
      end

      private

      attr_reader :runner
    end
  end
end
