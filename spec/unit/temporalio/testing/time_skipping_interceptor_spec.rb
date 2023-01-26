require 'temporalio/testing/time_skipping_interceptor'
require 'temporalio/testing/workflow_environment'

describe Temporalio::Testing::TimeSkippingInterceptor do
  subject { described_class.new(env) }
  let(:env) { instance_double(Temporalio::Testing::WorkflowEnvironment) }
  let(:handle) { instance_double(Temporalio::Client::WorkflowHandle) }
  let(:input) { Temporalio::Interceptor::Client::StartWorkflowInput.new }

  describe '#start_workflow' do
    before { allow(Temporalio::Testing::TimeSkippingHandle).to receive(:new).and_call_original }

    it 'returns a time skipping handle' do
      new_handle = subject.start_workflow(input) do |i|
        expect(i).to eq(input) # input remains unchanged
        handle
      end

      expect(new_handle).to be_a(Temporalio::Testing::TimeSkippingHandle)
      expect(Temporalio::Testing::TimeSkippingHandle).to have_received(:new).with(handle, env)
    end
  end
end
