require 'temporalio/connection'

module Temporalio
  RSpec.describe Connection do
    let(:address) { 'localhost:1234' }
    let(:core_connection) { instance_double(Bridge::Connection) }
    subject { described_class.new(address) }

    before do
      allow(Bridge::Connection).to receive(:connect).with(
        Runtime.instance.core_runtime, 'http://localhost:1234', Temporalio.identity, 'temporal-ruby', VERSION
      ).and_return(core_connection)
    end

    it 'initializes correctly' do
      expect(subject.core_connection).to eq core_connection
    end

    context 'when address format is not valid' do
      let(:address) { 'https://localhost:1234' }

      it { expect { subject }.to raise_error(Temporalio::Error, /Target host .* not supported/) }
    end
  end
end
