require 'temporalio/workflow/async'
require 'temporalio/workflow/future'

module Temporalio
  class Workflow
    class Context
      def initialize(runner, info, interceptors)
        @runner = runner
        @info = info
        @interceptors = interceptors
      end

      def async(&block)
        if block
          Temporalio::Workflow::Async.run(&block)
        else
          Temporalio::Workflow::Async
        end
      end

      def info
        interceptors.invoke(:workflow_info) { @info }
      end

      def sleep(duration)
        timer = start_timer(duration)
        timer.await
      end

      def start_timer(duration)
        Future.new do |future, resolve, reject|
          seq = runner.add_completion(:timer, resolve, reject)

          future.on_cancel do
            if runner.remove_completion(:timer, seq)
              runner.push_command(
                Coresdk::WorkflowCommands::WorkflowCommand.new(
                  cancel_timer: Coresdk::WorkflowCommands::CancelTimer.new(
                    seq: seq,
                  ),
                ),
              )
              reject.call(Future::Rejected.new('Timer canceled'))
            end
          end

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

      attr_reader :runner, :interceptors
    end
  end
end
