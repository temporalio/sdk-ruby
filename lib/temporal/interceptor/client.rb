module Temporal
  module Interceptor
    class Client
      StartWorkflowInput = Struct.new(
        :workflow,
        :args,
        :id,
        :task_queue,
        :execution_timeout,
        :run_timeout,
        :task_timeout,
        :id_reuse_policy,
        :retry_policy,
        :cron_schedule,
        :memo,
        :search_attributes,
        :headers,
        :start_signal,
        :start_signal_args,
        keyword_init: true,
      )

      DescribeWorkflowInput = Struct.new(
        :id,
        :run_id,
        keyword_init: true,
      )

      QueryWorkflowInput = Struct.new(
        :id,
        :run_id,
        :query,
        :args,
        :reject_condition,
        :headers,
        keyword_init: true,
      )

      SignalWorkflowInput = Struct.new(
        :id,
        :run_id,
        :signal,
        :args,
        :headers,
        keyword_init: true,
      )

      CancelWorkflowInput = Struct.new(
        :id,
        :run_id,
        :first_execution_run_id,
        :reason,
        keyword_init: true,
      )

      TerminateWorkflowInput = Struct.new(
        :id,
        :run_id,
        :first_execution_run_id,
        :reason,
        :args,
        keyword_init: true,
      )

      def start_workflow(input)
        yield(input)
      end

      def describe_workflow(input)
        yield(input)
      end

      def query_workflow(input)
        yield(input)
      end

      def signal_workflow(input)
        yield(input)
      end

      def cancel_workflow(input)
        yield(input)
      end

      def terminate_workflow(input)
        yield(input)
      end
    end
  end
end
