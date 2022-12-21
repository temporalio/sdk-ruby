require 'temporalio/payload_converter/composite'
require 'temporalio/payload_converter/bytes'
require 'temporalio/payload_converter/json'

describe Temporalio::PayloadConverter::Composite do
  subject { described_class.new(bytes_converter, json_converter) }

  let(:bytes_converter) { Temporalio::PayloadConverter::Bytes.new }
  let(:json_converter) { Temporalio::PayloadConverter::JSON.new }
  let(:bytes_payload) do
    Temporalio::Api::Common::V1::Payload.new(
      metadata: { 'encoding' => Temporalio::PayloadConverter::Bytes::ENCODING },
      data: 'test'.b,
    )
  end
  let(:json_payload) do
    Temporalio::Api::Common::V1::Payload.new(
      metadata: { 'encoding' => Temporalio::PayloadConverter::JSON::ENCODING },
      data: '"test"',
    )
  end

  describe '#to_payload' do
    before do
      allow(bytes_converter).to receive(:to_payload).and_call_original
      allow(json_converter).to receive(:to_payload).and_call_original
    end

    it 'tries converters until it finds a match' do
      results = [subject.to_payload('test'.b), subject.to_payload('test')]

      expect(results).to eq([bytes_payload, json_payload])
      expect(bytes_converter).to have_received(:to_payload).exactly(2).times
      expect(json_converter).to have_received(:to_payload).once
    end

    context 'when a converter could not be found' do
      # Exclude JSON converter because it can convert pretty much anything
      subject { described_class.new(bytes_converter) }

      it 'raises if an incoding' do
        expect { subject.to_payload('test') }.to raise_error(
          described_class::ConverterNotFound,
          'Available converters (Temporalio::PayloadConverter::Bytes) could not convert data'
        )
      end
    end
  end

  describe '#from_payload' do
    before do
      allow(bytes_converter).to receive(:from_payload).and_call_original
      allow(json_converter).to receive(:from_payload).and_call_original
    end

    it 'uses metadata to pick a converter' do
      subject.from_payload(bytes_payload)
      subject.from_payload(json_payload)

      expect(bytes_converter).to have_received(:from_payload).once
      expect(json_converter).to have_received(:from_payload).once
    end

    it 'raises when payload encoding is missing' do
      payload = Temporalio::Api::Common::V1::Payload.new(data: 'test')

      expect { subject.from_payload(payload) }.to raise_error(
        described_class::EncodingNotSet,
        'Missing payload encoding'
      )
    end

    it 'raises if there is no converter for an encoding' do
      payload = Temporalio::Api::Common::V1::Payload.new(metadata: { 'encoding' => 'fake' })

      expect { subject.from_payload(payload) }.to raise_error(
        described_class::ConverterNotFound,
        "Missing converter for encoding 'fake' (available: binary/plain, json/plain)"
      )
    end
  end
end
