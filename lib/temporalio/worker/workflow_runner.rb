require 'temporal/sdk/core/workflow_commands/workflow_commands_pb'
require 'temporalio/interceptor/workflow_inbound'
require 'temporalio/workflow/context'
require 'temporalio/workflow/info'

module Temporalio
  class Worker
    # @api private
    class WorkflowRunner
      class Completion < Struct.new(:resolve, :reject); end # rubocop:disable Lint/StructNewOverride

      def initialize(
        namespace,
        task_queue,
        workflow_class,
        run_id,
        worker,
        converter,
        inbound_interceptors,
        outbound_interceptors
      )
        @namespace = namespace
        @task_queue = task_queue
        @workflow_class = workflow_class
        @run_id = run_id
        @worker = worker
        @converter = converter
        @inbound_interceptors = inbound_interceptors
        @outbound_interceptors = outbound_interceptors
        @commands = []
        @sequences = Hash.new(0)
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
        next_seq = sequences[type] += 1
        completions[type][next_seq] = Completion.new(resolve, reject)
        next_seq
      end

      def remove_completion(type, seq)
        !!completions[type].delete(seq)
      end

      def finished?
        @finished
      end

      private

      attr_reader :namespace, :task_queue, :workflow_class, :run_id, :worker, :converter,
                  :inbound_interceptors, :outbound_interceptors, :commands, :completions,
                  :sequences, :fiber

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
        info = generate_workflow_info(job)
        context = Temporalio::Workflow::Context.new(self, info, outbound_interceptors)
        workflow = workflow_class.new(context)
        args = converter.from_payload_array(job.arguments.to_a)
        input = Temporalio::Interceptor::WorkflowInbound::ExecuteWorkflowInput.new(
          workflow: workflow_class,
          args: args,
          headers: info.headers,
        )

        @fiber = Fiber.new do
          result = inbound_interceptors.invoke(:execute_workflow, input) do |i|
            workflow.execute(*i.args)
          end

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
        completion = completions[:timer][job.seq]
        return unless completion

        completion.resolve.call(nil)
      end

      def generate_workflow_info(job)
        Temporalio::Workflow::Info.new(
          attempt: job.attempt,
          continued_run_id: job.continued_from_execution_run_id,
          cron_schedule: job.cron_schedule,
          execution_timeout: job.workflow_execution_timeout&.to_f,
          headers: converter.from_payload_map(job.headers) || {},
          namespace: namespace,
          parent: Temporalio::Workflow::ParentInfo.new(
            namespace: job.parent_workflow_info&.namespace,
            run_id: job.parent_workflow_info&.run_id,
            workflow_id: job.parent_workflow_info&.workflow_id,
          ),
          raw_memo: converter.from_payload_map(job.memo&.fields) || {},
          retry_policy: job.retry_policy ? Temporalio::RetryPolicy.from_proto(job.retry_policy) : nil,
          run_id: run_id,
          run_timeout: job.workflow_run_timeout&.to_f,
          search_attributes: converter.from_payload_map(job.search_attributes&.indexed_fields) || {},
          start_time: job.start_time&.to_time,
          task_queue: task_queue,
          task_timeout: job.workflow_task_timeout&.to_f,
          workflow_id: job.workflow_id,
          workflow_type: job.workflow_type,
        ).freeze
      end
    end
  end
end
