require 'temporalio/interceptor/workflow_inbound'

class TestWorkflowInboundInterceptor
  include Temporalio::Interceptor::WorkflowInbound
end

describe Temporalio::Interceptor::WorkflowInbound do
  subject { TestWorkflowInboundInterceptor.new }

  describe '#execute_workflow' do
    let(:input) { Temporalio::Interceptor::WorkflowInbound::ExecuteWorkflowInput.new }

    it 'yields' do
      expect { |b| subject.execute_workflow(input, &b) }.to yield_with_args(input)
    end
  end
end
