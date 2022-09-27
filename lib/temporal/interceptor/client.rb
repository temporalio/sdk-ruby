module Temporal
  module Interceptor
    class Client
      class StartWorkflowInput < Struct.new(
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
        :rpc_metadata,
        :rpc_timeout,
        keyword_init: true,
      ); end

      class DescribeWorkflowInput < Struct.new(
        :id,
        :run_id,
        :rpc_metadata,
        :rpc_timeout,
        keyword_init: true,
      ); end

      class QueryWorkflowInput < Struct.new(
        :id,
        :run_id,
        :query,
        :args,
        :reject_condition,
        :headers,
        :rpc_metadata,
        :rpc_timeout,
        keyword_init: true,
      ); end

      class SignalWorkflowInput < Struct.new(
        :id,
        :run_id,
        :signal,
        :args,
        :headers,
        :rpc_metadata,
        :rpc_timeout,
        keyword_init: true,
      ); end

      class CancelWorkflowInput < Struct.new(
        :id,
        :run_id,
        :first_execution_run_id,
        :reason,
        :rpc_metadata,
        :rpc_timeout,
        keyword_init: true,
      ); end

      class TerminateWorkflowInput < Struct.new(
        :id,
        :run_id,
        :first_execution_run_id,
        :reason,
        :args,
        :rpc_metadata,
        :rpc_timeout,
        keyword_init: true,
      ); end

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
