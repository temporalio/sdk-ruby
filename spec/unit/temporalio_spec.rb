require 'temporalio'

describe Temporalio do
  describe 'identity' do
    let(:expected) { "#{Process.pid}@#{Socket.gethostname} (Ruby SDK v#{Temporalio::VERSION})" }
    it { expect(described_class.identity).to eq(expected) }
  end
end
