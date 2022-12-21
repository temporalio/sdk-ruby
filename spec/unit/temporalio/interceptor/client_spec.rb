require 'temporalio/interceptor/client'

describe Temporalio::Interceptor::Client do
  subject { described_class.new }

  describe '#start_workflow' do
    let(:input) { Temporalio::Interceptor::Client::StartWorkflowInput.new }

    it 'yields' do
      expect { |b| subject.start_workflow(input, &b) }.to yield_with_args(input)
    end
  end

  describe '#describe_workflow' do
    let(:input) { Temporalio::Interceptor::Client::DescribeWorkflowInput.new }

    it 'yields' do
      expect { |b| subject.describe_workflow(input, &b) }.to yield_with_args(input)
    end
  end

  describe '#query_workflow' do
    let(:input) { Temporalio::Interceptor::Client::QueryWorkflowInput.new }

    it 'yields' do
      expect { |b| subject.query_workflow(input, &b) }.to yield_with_args(input)
    end
  end

  describe '#signal_workflow' do
    let(:input) { Temporalio::Interceptor::Client::SignalWorkflowInput.new }

    it 'yields' do
      expect { |b| subject.signal_workflow(input, &b) }.to yield_with_args(input)
    end
  end

  describe '#cancel_workflow' do
    let(:input) { Temporalio::Interceptor::Client::CancelWorkflowInput.new }

    it 'yields' do
      expect { |b| subject.cancel_workflow(input, &b) }.to yield_with_args(input)
    end
  end

  describe '#terminate_workflow' do
    let(:input) { Temporalio::Interceptor::Client::TerminateWorkflowInput.new }

    it 'yields' do
      expect { |b| subject.terminate_workflow(input, &b) }.to yield_with_args(input)
    end
  end
end
