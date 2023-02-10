module Temporalio
  module Interceptor
    # A mixin for implementing inbound Workflow interceptors.
    module WorkflowInbound
      class ExecuteWorkflowInput < Struct.new(
        :workflow,
        :args,
        :headers,
        keyword_init: true,
      ); end

      # Interceptor for {Temporalio::Workflow#execute}.
      #
      # @param input [ExecuteWorkflowInput]
      #
      # @return [any] Workflow execution result
      def execute_workflow(input)
        yield(input)
      end
    end
  end
end
