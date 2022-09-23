require 'securerandom'
require 'temporal/client/workflow_handle'
require 'temporal/client/implementation'
require 'temporal/workflow/execution_info'

describe Temporal::Client::WorkflowHandle do
  subject do
    described_class.new(
      client_impl,
      id,
      run_id: run_id,
      result_run_id: result_run_id,
      first_execution_run_id: first_execution_run_id,
    )
  end

  let(:client_impl) { instance_double(Temporal::Client::Implementation) }
  let(:id) { SecureRandom.uuid }
  let(:run_id) { SecureRandom.uuid }
  let(:result_run_id) { SecureRandom.uuid }
  let(:first_execution_run_id) { SecureRandom.uuid }

  describe '#result' do
    before { allow(client_impl).to receive(:await_workflow_result).and_return(42) }

    it 'calls the client implementation' do
      result = subject.result

      expect(result).to eq(42)
      expect(client_impl).to have_received(:await_workflow_result).with(id, result_run_id, true)
    end
  end

  describe '#describe' do
    let(:execution_info) { Temporal::Workflow::ExecutionInfo.new }

    before { allow(client_impl).to receive(:describe_workflow).and_return(execution_info) }

    it 'calls the client implementation' do
      result = subject.describe

      expect(result).to eq(execution_info)
      expect(client_impl).to have_received(:describe_workflow) do |input|
        expect(input).to be_a(Temporal::Interceptor::Client::DescribeWorkflowInput)
        expect(input.id).to eq(id)
        expect(input.run_id).to eq(run_id)
      end
    end
  end

  describe '#cancel' do
    before { allow(client_impl).to receive(:cancel_workflow) }

    it 'calls the client implementation' do
      subject.cancel('test reason')

      expect(client_impl).to have_received(:cancel_workflow) do |input|
        expect(input).to be_a(Temporal::Interceptor::Client::CancelWorkflowInput)
        expect(input.id).to eq(id)
        expect(input.run_id).to eq(run_id)
        expect(input.first_execution_run_id).to eq(first_execution_run_id)
        expect(input.reason).to eq('test reason')
      end
    end

    context 'without reason' do
      it 'calls the client implementation' do
        subject.cancel

        expect(client_impl).to have_received(:cancel_workflow) do |input|
          expect(input.reason).to eq(nil)
        end
      end
    end
  end

  describe '#query' do
    before { allow(client_impl).to receive(:query_workflow).and_return(42) }

    it 'calls the client implementation' do
      result = subject.query('test query', 1, 2, 3)

      expect(result).to eq(42)
      expect(client_impl).to have_received(:query_workflow) do |input|
        expect(input).to be_a(Temporal::Interceptor::Client::QueryWorkflowInput)
        expect(input.id).to eq(id)
        expect(input.run_id).to eq(run_id)
        expect(input.query).to eq('test query')
        expect(input.args).to eq([1, 2, 3])
        expect(input.reject_condition).to eq(Temporal::Workflow::QueryRejectCondition::NONE)
        expect(input.headers).to eq({})
      end
    end

    context 'without arguments' do
      it 'calls the client implementation' do
        result = subject.query('test query')

        expect(result).to eq(42)
        expect(client_impl).to have_received(:query_workflow) do |input|
          expect(input.query).to eq('test query')
          expect(input.args).to eq([])
        end
      end
    end

    context 'without arguments' do
      it 'calls the client implementation' do
        result = subject.query(
          'test query',
          reject_condition: Temporal::Workflow::QueryRejectCondition::NOT_OPEN,
        )

        expect(result).to eq(42)
        expect(client_impl).to have_received(:query_workflow) do |input|
          expect(input.query).to eq('test query')
          expect(input.args).to eq([])
          expect(input.reject_condition).to eq(Temporal::Workflow::QueryRejectCondition::NOT_OPEN)
        end
      end
    end
  end

  describe '#signal' do
    before { allow(client_impl).to receive(:signal_workflow) }

    it 'calls the client implementation' do
      subject.signal('test signal', 1, 2, 3)

      expect(client_impl).to have_received(:signal_workflow) do |input|
        expect(input).to be_a(Temporal::Interceptor::Client::SignalWorkflowInput)
        expect(input.id).to eq(id)
        expect(input.run_id).to eq(run_id)
        expect(input.signal).to eq('test signal')
        expect(input.args).to eq([1, 2, 3])
        expect(input.headers).to eq({})
      end
    end

    context 'without arguments' do
      it 'calls the client implementation' do
        subject.signal('test signal')

        expect(client_impl).to have_received(:signal_workflow) do |input|
          expect(input.signal).to eq('test signal')
          expect(input.args).to eq([])
        end
      end
    end
  end

  describe '#terminate' do
    before { allow(client_impl).to receive(:terminate_workflow) }

    it 'calls the client implementation' do
      subject.terminate('test reason', [1, 2, 3])

      expect(client_impl).to have_received(:terminate_workflow) do |input|
        expect(input).to be_a(Temporal::Interceptor::Client::TerminateWorkflowInput)
        expect(input.id).to eq(id)
        expect(input.run_id).to eq(run_id)
        expect(input.first_execution_run_id).to eq(first_execution_run_id)
        expect(input.reason).to eq('test reason')
        expect(input.args).to eq([1, 2, 3])
      end
    end

    context 'without reason and args' do
      it 'calls the client implementation' do
        subject.terminate

        expect(client_impl).to have_received(:terminate_workflow) do |input|
          expect(input.reason).to eq(nil)
          expect(input.args).to eq(nil)
        end
      end
    end
  end
end
