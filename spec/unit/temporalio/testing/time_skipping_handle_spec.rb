require 'temporalio/testing/time_skipping_handle'
require 'temporalio/testing/workflow_environment'

describe Temporalio::Testing::TimeSkippingHandle do
  subject { described_class.new(handle, env) }
  let(:env) { instance_double(Temporalio::Testing::WorkflowEnvironment) }
  let(:handle) do
    instance_double(
      Temporalio::Client::WorkflowHandle,
      id: nil,
      run_id: nil,
      result_run_id: nil,
      first_execution_run_id: nil,
      describe: nil,
      cancel: nil,
      query: nil,
      signal: nil,
      terminate: nil,
    )
  end

  describe '#id' do
    it 'delegates the call to the original handle' do
      subject.id
      expect(handle).to have_received(:id)
    end
  end

  describe '#run_id' do
    it 'delegates the call to the original handle' do
      subject.run_id
      expect(handle).to have_received(:run_id)
    end
  end

  describe '#result_run_id' do
    it 'delegates the call to the original handle' do
      subject.result_run_id
      expect(handle).to have_received(:result_run_id)
    end
  end

  describe '#first_execution_run_id' do
    it 'delegates the call to the original handle' do
      subject.first_execution_run_id
      expect(handle).to have_received(:first_execution_run_id)
    end
  end

  describe '#describe' do
    it 'delegates the call to the original handle' do
      subject.describe
      expect(handle).to have_received(:describe)
    end
  end

  describe '#cancel' do
    it 'delegates the call to the original handle' do
      subject.cancel
      expect(handle).to have_received(:cancel)
    end
  end

  describe '#query' do
    it 'delegates the call to the original handle' do
      subject.query('test-query')
      expect(handle).to have_received(:query).with('test-query')
    end
  end

  describe '#signal' do
    it 'delegates the call to the original handle' do
      subject.signal('test-signal')
      expect(handle).to have_received(:signal).with('test-signal')
    end
  end

  describe '#terminate' do
    it 'delegates the call to the original handle' do
      subject.terminate
      expect(handle).to have_received(:terminate)
    end
  end

  describe '#result' do
    before do
      allow(handle).to receive(:result).and_return(42)
      allow(env).to receive(:with_time_skipping).and_yield
    end

    it 'wraps the call in #with_time_skipping' do
      expect(subject.result).to eq(42)
      expect(env).to have_received(:with_time_skipping)
    end
  end
end
