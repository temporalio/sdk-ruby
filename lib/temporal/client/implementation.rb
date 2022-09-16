require 'temporal/client/workflow_handle'
require 'temporal/interceptor/chain'
require 'temporal/version'
require 'temporal/workflow/execution_info'
require 'temporal/workflow/id_reuse_policy'
require 'temporal/workflow/query_reject_condition'

module Temporal
  class Client
    class Implementation
      def initialize(connection, namespace, converter, interceptors)
        @connection = connection
        @namespace = namespace
        @converter = converter
        @interceptor_chain = Interceptor::Chain.new(interceptors)
        @identity = "#{Process.pid}@#{Socket.gethostname} (Ruby SDK v#{VERSION})"
      end

      def start_workflow(input)
        interceptor_chain.invoke(:start_workflow, input) do |i|
          handle_start_workflow(i)
        end
      end

      def describe_workflow(input)
        interceptor_chain.invoke(:describe_workflow, input) do |i|
          handle_describe_workflow(i)
        end
      end

      def query_workflow(input)
        interceptor_chain.invoke(:query_workflow, input) do |i|
          handle_query_workflow(i)
        end
      end

      def signal_workflow(input)
        interceptor_chain.invoke(:signal_workflow, input) do |i|
          handle_signal_workflow(i)
        end
      end

      def cancel_workflow(input)
        interceptor_chain.invoke(:cancel_workflow, input) do |i|
          handle_cancel_workflow(i)
        end
      end

      def terminate_workflow(input)
        interceptor_chain.invoke(:terminate_workflow, input) do |i|
          handle_terminate_workflow(i)
        end
      end

      # TODO: Add timeout and follow_runs
      def await_workflow_result(id, run_id)
        request = Temporal::Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest.new(
          namespace: namespace,
          execution: Temporal::Api::Common::V1::WorkflowExecution.new(
            workflow_id: id,
            run_id: run_id || '',
          ),
          history_event_filter_type:
            Temporal::Api::Enums::V1::HistoryEventFilterType::HISTORY_EVENT_FILTER_TYPE_CLOSE_EVENT,
          wait_new_event: true,
          skip_archival: true,
        )

        loop do
          response = connection.get_workflow_execution_history(request)
          catch(:next) do
            return process_workflow_result_from(response)
          end
        end
      end

      private

      attr_reader :connection, :namespace, :converter, :interceptor_chain, :identity

      def handle_start_workflow(input)
        input.retry_policy&.validate!

        if input.memo
          memo = Temporal::Api::Common::V1::Memo.new(fields: converter.to_payload_map(input.memo))
        end

        if input.search_attributes
          search_attributes = Temporal::Api::Common::V1::SearchAttributes.new(
            indexed_fields: converter.to_payload_map(input.search_attributes),
          )
        end

        unless input.headers.empty?
          headers = Temporal::Api::Common::V1::Header.new(
            fields: converter.to_payload_map(input.headers),
          )
        end

        params = {
          identity: identity,
          request_id: SecureRandom.uuid,
          namespace: namespace,
          workflow_type: Temporal::Api::Common::V1::WorkflowType.new(name: input.workflow.to_s),
          workflow_id: input.id,
          task_queue: Temporal::Api::TaskQueue::V1::TaskQueue.new(name: input.task_queue),
          input: converter.to_payloads(input.args),
          workflow_execution_timeout: input.execution_timeout,
          workflow_run_timeout: input.run_timeout,
          workflow_task_timeout: input.task_timeout,
          workflow_id_reuse_policy: Workflow::IDReusePolicy.to_raw(input.id_reuse_policy),
          retry_policy: nil, # TODO: serialize retry policy
          cron_schedule: input.cron_schedule,
          memo: memo,
          search_attributes: search_attributes,
          header: headers,
        }

        first_execution_run_id = nil
        if input.start_signal
          params.merge!(
            signal_name: input.start_signal,
            signal_input: converter.to_payloads(input.start_signal_args),
          )

          klass = Temporal::Api::WorkflowService::V1::SignalWithStartWorkflowExecutionRequest
          request = klass.new(**params)

          response = connection.signal_with_start_workflow_execution(request)
        else
          klass = Temporal::Api::WorkflowService::V1::StartWorkflowExecutionRequest
          request = klass.new(**params)

          response = connection.start_workflow_execution(request)
          first_execution_run_id = response.run_id
        end

        Client::WorkflowHandle.new(
          self,
          input.id,
          result_run_id: response.run_id,
          first_execution_run_id: first_execution_run_id,
        )
      rescue Temporal::Bridge::Error => e
        # TODO: Raise a better error from the bridge
        if e.message.include?('AlreadyExists')
          # TODO: Replace with a more specific error
          raise Temporal::Error, 'Workflow already exists'
        end
      end

      def handle_describe_workflow(input)
        request = Temporal::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest.new(
          namespace: namespace,
          execution: Temporal::Api::Common::V1::WorkflowExecution.new(
            workflow_id: input.id,
            run_id: input.run_id || '',
          ),
        )

        response = connection.describe_workflow_execution(request)

        Workflow::ExecutionInfo.from_raw(response, converter)
      end

      def handle_query_workflow(input)
        request = Temporal::Api::WorkflowService::V1::QueryWorkflowRequest.new(
          namespace: namespace,
          execution: Temporal::Api::Common::V1::WorkflowExecution.new(
            workflow_id: input.id,
            run_id: input.run_id,
          ),
          query: Temporal::Api::Query::V1::WorkflowQuery.new(
            query_type: input.query,
            query_args: converter.to_payloads(input.args),
          ),
          query_reject_condition: Workflow::QueryRejectCondition.to_raw(input.reject_condition),
        )

        response = connection.query_workflow(request)

        if response.query_rejected
          status = Workflow::ExecutionStatus.from_raw(response.query_rejected.status)
          # TODO: Replace with a specific error when implemented
          raise Temporal::Error, "Query rejected, workflow status: #{status}"
        end

        converter.from_payloads(response.query_result)&.first
      rescue Temporal::Bridge::Error => e
        # TODO: Raise a better error from the bridge
        if e.message.include?('unknown queryType')
          # TODO: Replace with a more specific error
          raise Temporal::Error, 'Unsupported query'
        end
      end

      def handle_signal_workflow(input)
        request = Temporal::Api::WorkflowService::V1::SignalWorkflowExecutionRequest.new(
          identity: identity,
          request_id: SecureRandom.uuid,
          namespace: namespace,
          workflow_execution: Temporal::Api::Common::V1::WorkflowExecution.new(
            workflow_id: input.id,
            run_id: input.run_id || '',
          ),
          signal_name: input.signal,
          input: converter.to_payloads(input.args),
          header: nil, # TODO: converter.to_payloads headers
        )

        connection.signal_workflow_execution(request)

        return
      end

      def handle_cancel_workflow(input)
        request = Temporal::Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest.new(
          identity: identity,
          request_id: SecureRandom.uuid,
          namespace: namespace,
          workflow_execution: Temporal::Api::Common::V1::WorkflowExecution.new(
            workflow_id: input.id,
            run_id: input.run_id || '',
          ),
          first_execution_run_id: input.first_execution_run_id || '',
          reason: input.reason,
        )

        connection.request_cancel_workflow_execution(request)

        return
      end

      def handle_terminate_workflow(input)
        request = Temporal::Api::WorkflowService::V1::TerminateWorkflowExecutionRequest.new(
          identity: identity,
          namespace: namespace,
          workflow_execution: Temporal::Api::Common::V1::WorkflowExecution.new(
            workflow_id: input.id,
            run_id: input.run_id || '',
          ),
          first_execution_run_id: input.first_execution_run_id || '',
          reason: input.reason,
          details: converter.to_payloads(input.args),
        )

        connection.terminate_workflow_execution(request)

        return
      end

      def process_workflow_result_from(response)
        if response.history.events.empty?
          throw(:next) # next loop iteration
        elsif response.history.events.length != 1
          raise Temporal::Error, "Expected single close event, got #{response.history.events.length}"
        end

        event = response.history.events.first

        case event.event_type
        when :EVENT_TYPE_WORKFLOW_EXECUTION_COMPLETED
          attributes = event.workflow_execution_completed_event_attributes
          # TODO: Handle incorrect payloads object
          return converter.from_payloads(attributes.result)&.first

        when :EVENT_TYPE_WORKFLOW_EXECUTION_FAILED
          # TODO: Use more specific error and decode failure
          raise Temporal::Error, 'Workflow execution failed'

        when :EVENT_TYPE_WORKFLOW_EXECUTION_CANCELED
          # TODO: Use more specific error and decode failure
          raise Temporal::Error, 'Workflow execution cancelled'

        when :EVENT_TYPE_WORKFLOW_EXECUTION_TERMINATED
          # TODO: Use more specific error and decode failure
          raise Temporal::Error, 'Workflow execution terminated'

        when :EVENT_TYPE_WORKFLOW_EXECUTION_TIMED_OUT
          # TODO: Use more specific error and decode failure
          raise Temporal::Error, 'Workflow execution timed out'

        when :EVENT_TYPE_WORKFLOW_EXECUTION_CONTINUED_AS_NEW
          # TODO: Use more specific error and decode failure
          raise Temporal::Error, 'Workflow execution continued as new'
        end
      end
    end
  end
end
