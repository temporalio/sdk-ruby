require 'temporal/activity/context'
require 'temporal/activity/info'

describe Temporal::Activity::Context do
  subject { described_class.new(info, heartbeat) }
  let(:info) { Temporal::Activity::Info.new }
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
            subject.instance_variable_set(:@cancelled, true)
          end
        end.to raise_error(Temporal::Error::CancelledError, 'Unhandled cancellation')
      end
    end

    context 'when whole context is shielded' do
      subject { described_class.new(info, heartbeat, shielded: true) }

      it 'ignores cancellation' do
        expect(
          subject.shield do
            subject.instance_variable_set(:@cancelled, true)
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
              subject.instance_variable_set(:@cancelled, true)
              42
            end

            expect(result).to eq(42)
          end.to raise_error(Temporal::Error::CancelledError, 'Unhandled cancellation')
        end
      end
    end

    context 'when called on an already cancelled context' do
      it 'has no effect' do
        subject.cancel rescue nil # rubocop:disable Style/RescueModifier

        expect(subject.shield { 42 }).to eq(42)
      end
    end
  end

  describe '#cancelled?' do
    it 'returns false when not cancelled' do
      expect(subject).not_to be_cancelled
    end

    it 'returns true when cancelled' do
      subject.cancel rescue nil # rubocop:disable Style/RescueModifier
      expect(subject).to be_cancelled
    end
  end

  describe '#cancel' do
    it 'raises an error' do
      expect do
        subject.cancel
      end.to raise_error(Temporal::Error::CancelledError, 'Unhandled cancellation')
    end

    context 'when shielded' do
      before { subject.instance_variable_set(:@shielded, true) }

      it 'does not raise an error' do
        subject.cancel
        expect(subject).to be_cancelled
      end
    end
  end
end
