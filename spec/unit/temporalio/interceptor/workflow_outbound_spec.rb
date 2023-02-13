require 'temporalio/interceptor/workflow_outbound'

class TestWorkflowOutboundInterceptor
  include Temporalio::Interceptor::WorkflowOutbound
end

describe Temporalio::Interceptor::WorkflowOutbound do
  subject { TestWorkflowOutboundInterceptor.new }

  describe '#workflow_info' do
    it 'yields' do
      expect { |b| subject.workflow_info(&b) }.to yield_control
    end
  end
end
