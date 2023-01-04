require 'temporalio/activity/context'
require 'temporalio/activity/info'

describe Temporalio::Activity::Context do
  subject { described_class.new(info, heartbeat) }
  let(:info) { Temporalio::Activity::Info.new }
  let(:heartbeat) { ->(*_) {} }

  describe '#heartbeat' do
    it 'calls the provided proc' do
      received_details = nil
      heartbeat = ->(*details) { received_details = details }

      context = described_class.new(info, heartbeat)
      context.heartbeat('foo', 'bar')

      expect(received_details).to eq(%w[foo bar])
    end
  end

  describe '#shield' do
    it 'calls provided block' do
      expect { |block| subject.shield(&block) }.to yield_control
    end

    it 'returns block result' do
      expect(subject.shield { 42 }).to eq(42)
    end

    context 'when block raises' do
      it 're-raises the error' do
        expect { subject.shield { raise 'test error' } }.to raise_error('test error')
      end
    end

    context 'when cancelled while shielded' do
      it 'raises after finishing the block' do
        expect do
          subject.shield do
            subject.cancel('Test cancellation')
          end
        end.to raise_error(Temporalio::Error::ActivityCancelled, 'Test cancellation')
      end
    end

    context 'when whole context is shielded' do
      subject { described_class.new(info, heartbeat, shielded: true) }

      it 'ignores cancellation' do
        expect(
          subject.shield do
            subject.cancel('Test cancellation')
            42
          end
        ).to eq(42)
      end
    end

    context 'when nested' do
      it 'has no effect' do
        expect do
          subject.shield do
            result = subject.shield do
              subject.cancel('Test cancellation')
              42
            end

            expect(result).to eq(42)
          end.to raise_error(Temporalio::Error::ActivityCancelled, 'Test cancellation')
        end
      end
    end

    context 'when called on an already cancelled context' do
      it 'has no effect' do
        subject.cancel('Test cancellation', true) rescue nil # rubocop:disable Style/RescueModifier

        expect(subject.shield { 42 }).to eq(42)
      end
    end

    context 'when called from a different thread' do
      it 'warns' do
        # create contex from another thread
        context = Thread.new { subject }.value
        allow(context).to receive(:warn)

        expect(context.shield { 42 }).to eq(42)
        expect(context)
          .to have_received(:warn)
          .with("Activity shielding is not intended to be used outside of activity's thread.")
      end
    end
  end

  describe '#cancelled?' do
    it 'returns false when not cancelled' do
      expect(subject).not_to be_cancelled
    end

    it 'returns true when cancelled' do
      subject.cancel('Test cancellation') rescue nil # rubocop:disable Style/RescueModifier
      expect(subject).to be_cancelled
    end
  end

  describe '#cancel' do
    it 'raises a non-requested cancellation error' do
      expect do
        subject.cancel('Test cancellation', by_request: false)
      end.to raise_error do |error|
        expect(error).to be_a(Temporalio::Error::ActivityCancelled)
        expect(error.message).to eq('Test cancellation')
        expect(error).not_to be_by_request
      end
    end

    it 'raises a cancellation by request' do
      expect do
        subject.cancel('Test cancellation', by_request: true)
      end.to raise_error do |error|
        expect(error).to be_a(Temporalio::Error::ActivityCancelled)
        expect(error.message).to eq('Test cancellation')
        expect(error).to be_by_request
      end
    end

    context 'when shielded' do
      before { subject.instance_variable_set(:@shielded, true) }

      it 'does not raise an error' do
        subject.cancel('Test cancellation')
        expect(subject).to be_cancelled
      end
    end
  end
end
