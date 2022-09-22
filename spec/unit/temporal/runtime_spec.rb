require 'temporal/runtime'

describe Temporal::Runtime do
  subject { described_class.instance }

  describe '#ensure_callback_loop' do
    let(:mock_runtime) { instance_double(Temporal::Bridge::Runtime, run_callback_loop: nil) }

    before do
      allow(subject).to receive(:core_runtime).and_return(mock_runtime)
    end

    it 'runs the callback loop once' do
      subject.ensure_callback_loop
      subject.instance_variable_get(:@thread).join # allow thread to run
      subject.ensure_callback_loop

      expect(mock_runtime).to have_received(:run_callback_loop).once
    end
  end
end
