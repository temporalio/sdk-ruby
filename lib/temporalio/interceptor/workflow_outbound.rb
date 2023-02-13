module Temporalio
  module Interceptor
    # A mixin for implementing outbound Workflow interceptors.
    module WorkflowOutbound
      # Interceptor for {Temporalio::Workflow::Context#info}.
      #
      # @yieldreturn Temporalio::Workflow::Info
      #
      # @return [Temporalio::Workflow::Info]
      def workflow_info
        yield
      end
    end
  end
end
