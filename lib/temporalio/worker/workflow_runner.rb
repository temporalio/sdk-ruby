# require 'google/protobuf/well_known_types'
require 'temporalio/workflow/context'
# require 'temporalio/workflow/info'
# require 'temporalio/error/failure'
# require 'temporalio/errors'
# require 'temporalio/interceptor/workflow_inbound'

module Temporalio
  class Worker
    # @api private
    class WorkflowRunner
      class Completion < Struct.new(:resolve, :reject); end # rubocop:disable Lint/StructNewOverride

      def initialize(
        workflow_class,
        worker,
        converter
      )
        @workflow_class = workflow_class
        @worker = worker
        @converter = converter
        @commands = []
        # TODO: Encapsulate logic for adding new completions
        @completions = Hash.new({})
        @fiber = nil # the root Fiber for executing a workflow
        @finished = false
      end

      # TODO: Move this to a thread dedicated to workflows to avoid blocking the main reactor
      def process(activation)
        # Each activation produces its own list of commands, clear previous ones
        commands.clear

        order_jobs(activation.jobs).each do |job|
          apply(job)
        end

        # TODO: process conditional blocks here

        commands
      end

      def push_command(command)
        commands << command
      end

      def add_completion(type, resolve, reject)
        next_seq = (completions[type].keys.max || 0) + 1
        completions[type][next_seq] = Completion.new(resolve, reject)
        next_seq
      end

      def finished?
        @finished
      end

      # def schedule_fiber(fiber, value)

      # end

      private

      attr_reader :workflow_class, :worker, :converter, :commands, :completions, :fiber

      def order_jobs(jobs)
        # Process patches first, then signals, then non-queries and finally queries
        jobs.each_with_object([[], [], [], []]) do |job, result|
          if job.notify_has_patch
            result[0] << job
          elsif job.signal_workflow
            result[1] << job
          elsif job.query_workflow
            result[3] << job
          else
            result[2] << job
          end
        end.flatten
      end

      # TODO: This isn't fully implemented yet and will be gradually populated
      def apply(job)
        if job.start_workflow
          apply_start_workflow(job.start_workflow)
        elsif job.fire_timer
          apply_fire_timer(job.fire_timer)
        elsif job.remove_from_cache
          # Ignore, handled externally
        else
          raise "Unrecognized job: #{job.variant}"
        end
      end

      def apply_start_workflow(job)
        # TODO: Generate workflow info
        context = Temporalio::Workflow::Context.new(self)
        workflow = workflow_class.new(context)
        args = converter.from_payload_array(job.arguments.to_a)

        @fiber = Fiber.new do
          result = workflow.execute(*args)

          push_command(
            Coresdk::WorkflowCommands::WorkflowCommand.new(
              complete_workflow_execution: Coresdk::WorkflowCommands::CompleteWorkflowExecution.new(
                result: converter.to_payload(result),
              ),
            ),
          )
        rescue StandardError => e
          push_command(
            Coresdk::WorkflowCommands::WorkflowCommand.new(
              fail_workflow_execution: Coresdk::WorkflowCommands::FailWorkflowExecution.new(
                failure: converter.to_failure(e),
              ),
            ),
          )
        ensure
          @finished = true
        end

        @fiber&.resume
      end

      def apply_fire_timer(job)
        # TODO: [maybe] Send ready Fibers to a queue instead of resuming in place
        completions[:timer][job.seq].resolve.call(nil)
      end
    end
  end
end
