require 'temporal/sdk/core/workflow_commands/workflow_commands_pb'
require 'temporalio/error/failure'
require 'temporalio/errors'
require 'temporalio/interceptor/chain'
require 'temporalio/interceptor/workflow_inbound'
require 'temporalio/interceptor/workflow_outbound'
require 'temporalio/worker/sync_worker'
require 'temporalio/worker/workflow_runner'

module Temporalio
  class Worker
    # @api private
    class WorkflowWorker
      def initialize(task_queue, core_worker, workflows, converter, interceptors)
        @task_queue = task_queue
        # TODO: Make activity/workflow share the same instance
        @worker = SyncWorker.new(core_worker)
        @workflows = prepare_workflows(workflows)
        @converter = converter
        @inbound_interceptors = Temporalio::Interceptor::Chain.new(filter_inbound(interceptors))
        @outbound_interceptors = Temporalio::Interceptor::Chain.new(filter_outbound(interceptors))
        @drain_queue = Queue.new
        @running_workflows = {}
      end

      def run(reactor)
        # @type var outstanding_tasks: Array[Async::Task]
        outstanding_tasks = []

        loop do
          workflow_activation = worker.poll_workflow_activation
          outstanding_tasks << reactor.async do |async_task|
            handle_activation(workflow_activation)
          ensure
            outstanding_tasks.delete(async_task)
          end
        end
      rescue Temporalio::Bridge::Error::WorkerShutdown
        # No need to re-raise this error, it's a part of a normal shutdown
      ensure
        outstanding_tasks.each(&:wait)
        drain_queue.close
      end

      def drain
        drain_queue.pop
      end

      private

      attr_reader :task_queue, :worker, :workflows, :converter, :inbound_interceptors,
                  :outbound_interceptors, :drain_queue, :running_workflows

      def prepare_workflows(workflows)
        workflows.each_with_object({}) do |workflow, result|
          unless workflow.ancestors.include?(Temporalio::Workflow)
            raise ArgumentError, 'Workflow must be a subclass of Temporalio::Workflow'
          end

          if result[workflow._name]
            raise ArgumentError, "More than one workflow named #{workflow._name}"
          end

          result[workflow._name] = workflow
          result
        end
      end

      # NOTE: Using #each_with_object here and below instead of a simple #select because RBS can't
      #       reconcile that resulting array only has WorkflowInbound or WorkflowOutbound in it.
      def filter_inbound(interceptors)
        interceptors.each_with_object([]) do |i, result|
          result << i if i.is_a?(Temporalio::Interceptor::WorkflowInbound)
        end
      end

      def filter_outbound(interceptors)
        interceptors.each_with_object([]) do |i, result|
          result << i if i.is_a?(Temporalio::Interceptor::WorkflowOutbound)
        end
      end

      def lookup_workflow(workflow_type)
        workflows.fetch(workflow_type) do
          workflow_names = workflows.keys.sort.join(', ')
          raise Temporalio::Error::ApplicationError.new(
            "Workflow #{workflow_type} is not registered on this worker, available workflows: #{workflow_names}",
            type: 'NotFoundError',
          )
        end
      end

      def get_or_create_workflow_runner(activation)
        running_workflows.fetch(activation.run_id) do
          start = activation.jobs.find(&:start_workflow)&.start_workflow
          unless start
            raise 'Missing start workflow, workflow could have unexpectedly been removed from cache'
          end

          workflow = lookup_workflow(start.workflow_type)
          runner = WorkflowRunner.new(
            workflow,
            worker,
            converter,
            inbound_interceptors,
            outbound_interceptors,
          )

          running_workflows[activation.run_id] = runner
        end
      end

      def handle_activation(activation)
        # TODO: Decode the whole activation on a separate thread

        commands = []

        if activation.jobs.any? { |job| !job.remove_from_cache }
          runner = get_or_create_workflow_runner(activation)
          commands += runner.process(activation)
        end

        # TODO: Encode all commands on a separate thread

        worker.complete_workflow_activation_with_success(activation.run_id, commands)

        if runner&.finished? || activation.jobs.any?(&:remove_from_cache)
          running_workflows.delete(activation.run_id)
        end
      end
    end
  end
end
