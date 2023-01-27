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
      def initialize(
        workflow_class,
        worker,
        converter
      )
        @workflow_class = workflow_class
        @worker = worker
        @converter = converter
        @commands = []
      end

      def process(activation)
        # Each activation produces its own list of commands
        commands.clear

        order_jobs(activation.jobs).each do |job|
          apply(job)
        end

        commands
      end

      private

      attr_reader :workflow_class, :worker, :converter, :commands

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
        elsif job.remove_from_cache
          # Ignore, handled externally
        else
          raise RuntimeError("Unrecognized job: #{job.variant}")
        end
      end

      def apply_start_workflow(job)
        # TODO: Generate workflow info
        context = Temporalio::Workflow::Context.new
        workflow = workflow_class.new(context)
        args = converter.from_payload_array(job.arguments.to_a)

        # TODO: This needs to be wrapped in a Fiber
        result = workflow.execute(*args)

        commands << Coresdk::WorkflowCommands::WorkflowCommand.new(
          complete_workflow_execution: Coresdk::WorkflowCommands::CompleteWorkflowExecution.new(
            result: converter.to_payload(result),
          )
        )
      rescue StandardError => e
        commands << Coresdk::WorkflowCommands::WorkflowCommand.new(
          fail_workflow_execution: Coresdk::WorkflowCommands::FailWorkflowExecution.new(
            failure: converter.to_failure(e),
          )
        )
      end
    end
  end
end
