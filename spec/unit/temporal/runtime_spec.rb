require 'temporal/runtime'

describe Temporal::Runtime do
  subject { described_class.instance }

  describe '#ensure_callback_loop' do
    let(:mock_runtime) { double(Temporal::Bridge::Runtime, run_callback_loop: nil) }

    before do
      allow(subject).to receive(:core_runtime).and_return(mock_runtime)
    end

    it 'runs the callback loop' do
      subject.ensure_callback_loop

      expect(mock_runtime).to have_received(:run_callback_loop)
    end

    it 'does not run callback loop twice' do
      subject.ensure_callback_loop

      expect(mock_runtime).not_to have_received(:run_callback_loop)
    end
  end
end
