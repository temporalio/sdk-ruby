require 'support/helpers/test_capture_interceptor'
require 'temporalio/workflow/context'

describe Temporalio::Workflow::Context do
  subject do
    described_class.new(
      runner,
      rand_seed,
      info,
      Temporalio::Interceptor::Chain.new(interceptors),
    )
  end

  let(:runner) { instance_double(Temporalio::Worker::WorkflowRunner) }
  let(:rand_seed) { 123 }
  let(:info) { instance_double(Temporalio::Workflow::Info) }
  let(:interceptors) { [] }

  describe '#async' do
    it 'returns the Async module' do
      expect(subject.async).to eq(Temporalio::Workflow::Async)
    end

    context 'when given a block' do
      before { allow(Temporalio::Workflow::Async).to receive(:run).and_call_original }

      it 'calls the run method on Async' do
        future = subject.async { 42 }

        expect(Temporalio::Workflow::Async).to have_received(:run)
        expect(future).to be_a(Temporalio::Workflow::Future)
        expect(future.await).to eq(42)
      end
    end
  end

  describe '#time' do
    let(:time) { Time.now }
    before { allow(runner).to receive(:time).and_return(time) }

    it 'delegates the call to the runner' do
      expect(subject.time).to eq(time)
      expect(runner).to have_received(:time)
    end

    it 'works with a #now alias' do
      expect(subject.now).to eq(time)
      expect(runner).to have_received(:time)
    end
  end

  describe '#rand' do
    it 'returns a random number based on the seed' do
      # Numbers are pre-generated based on the 123 seed
      expect(subject.rand(100)).to eq(66)
      expect(subject.rand(100)).to eq(92)
      expect(subject.rand(100)).to eq(98)
    end
  end

  describe '#info' do
    it 'returns workflow info' do
      expect(subject.info).to eq(info)
    end

    context 'with interceptors' do
      let(:interceptor) { Helpers::TestCaptureInterceptor.new }
      let(:interceptors) { [interceptor] }

      it 'wraps call in an interceptor' do
        subject.info

        expect(interceptor.called_methods).to eq([:workflow_info])
      end
    end
  end

  describe '#start_timer' do
    let(:seq) { 1 }
    let(:duration) { 42 }
    let(:start_timer_command) do
      Temporalio::Bridge::Api::WorkflowCommands::WorkflowCommand.new(
        start_timer: Temporalio::Bridge::Api::WorkflowCommands::StartTimer.new(
          seq: seq,
          start_to_fire_timeout: Google::Protobuf::Duration.new(seconds: duration),
        ),
      )
    end
    let(:cancel_timer_command) do
      Temporalio::Bridge::Api::WorkflowCommands::WorkflowCommand.new(
        cancel_timer: Temporalio::Bridge::Api::WorkflowCommands::CancelTimer.new(seq: seq),
      )
    end

    before do
      allow(runner)
        .to receive(:add_completion)
        .with(:timer, an_instance_of(Proc), an_instance_of(Proc))
        .and_return(seq)
      allow(runner).to receive(:remove_completion).with(:timer, seq).and_return(true)
      allow(runner).to receive(:push_command)
    end

    it 'returns a future' do
      future = subject.start_timer(duration)

      expect(future).to be_a(Temporalio::Workflow::Future)
      expect(future).to be_pending
    end

    it 'starts a timer' do
      subject.start_timer(duration)

      expect(runner)
        .to have_received(:add_completion)
        .with(:timer, an_instance_of(Proc), an_instance_of(Proc))
      expect(runner).to have_received(:push_command).with(start_timer_command)
    end

    context 'cancellation' do
      it 'cancels the timer' do
        future = subject.start_timer(duration)

        expect(future).to be_pending
        expect(runner).to have_received(:push_command).with(start_timer_command)

        future.cancel

        expect(future).to be_rejected
        expect { future.await }.to raise_error(Temporalio::Workflow::Future::Rejected, 'Timer canceled')
        expect(runner).to have_received(:remove_completion).with(:timer, seq)
        expect(runner).to have_received(:push_command).with(cancel_timer_command)
      end
    end
  end
end
