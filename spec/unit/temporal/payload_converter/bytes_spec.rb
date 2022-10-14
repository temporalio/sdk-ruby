require 'temporal/payload_converter/bytes'

describe Temporal::PayloadConverter::Bytes do
  subject { described_class.new }

  describe 'round trip' do
    it 'encodes to a binary/plain payload' do
      payload = Temporal::Api::Common::V1::Payload.new(
        metadata: { 'encoding' => described_class::ENCODING },
        data: 'test'.b
      )

      expect(subject.to_payload('test'.b)).to eq(payload)
    end

    it 'decodes a binary/plain payload to a byte string' do
      payload = Temporal::Api::Common::V1::Payload.new(
        metadata: { 'encoding' => described_class::ENCODING },
        data: 'test'.b
      )

      expect(subject.from_payload(payload)).to eq('test'.b)
      expect(subject.from_payload(payload).encoding).to eq(Encoding::ASCII_8BIT)
    end
  end
end
