require 'temporal/data_converter'
require 'temporal/payload_converter'

describe Temporal::DataConverter do
  subject { described_class.new(payload_converter: converter) }
  let(:converter) { Temporal::PayloadConverter::DEFAULT }
  let(:nil_payload) do
    Temporal::Api::Common::V1::Payload.new(
      metadata: { 'encoding' => Temporal::PayloadConverter::Nil::ENCODING },
    )
  end
  let(:json_payload) do
    Temporal::Api::Common::V1::Payload.new(
      metadata: { 'encoding' => Temporal::PayloadConverter::JSON::ENCODING },
      data: '"test"',
    )
  end

  before do
    allow(converter).to receive(:to_payload).and_call_original
    allow(converter).to receive(:from_payload).and_call_original
  end

  describe '#to_payloads' do
    it 'returns nil when nil given' do
      expect(subject.to_payloads(nil)).to eq(nil)
    end

    it 'converts a single value to payloads' do
      result = subject.to_payloads('test')

      expect(result).to be_a(Temporal::Api::Common::V1::Payloads)
      expect(result.payloads.length).to eq(1)
      expect(result.payloads.first).to eq(json_payload)
      expect(converter).to have_received(:to_payload).with('test').once
    end

    it 'converts an array to payloads' do
      result = subject.to_payloads(['test', nil])

      expect(result).to be_a(Temporal::Api::Common::V1::Payloads)
      expect(result.payloads.length).to eq(2)
      expect(result.payloads.first).to eq(json_payload)
      expect(result.payloads.last).to eq(nil_payload)
      expect(converter).to have_received(:to_payload).with('test').once
      expect(converter).to have_received(:to_payload).with(nil).once
    end
  end

  describe '#to_payload_map' do
    it 'handles empty hash' do
      result = subject.to_payload_map({})

      expect(result).to eq({})
      expect(converter).not_to have_received(:to_payload)
    end

    it 'converts a hash to payload hash' do
      result = subject.to_payload_map({ 'one' => 'test', 'two' => nil })

      expect(result.length).to eq(2)
      expect(result['one']).to eq(json_payload)
      expect(result['two']).to eq(nil_payload)
      expect(converter).to have_received(:to_payload).with('test').once
      expect(converter).to have_received(:to_payload).with(nil).once
    end
  end

  describe '#from_payloads' do
    it 'returns nil when nothing is given' do
      expect(subject.from_payloads(nil)).to eq(nil)
    end

    it 'returns original payload values' do
      payloads = Temporal::Api::Common::V1::Payloads.new(payloads: [json_payload, nil_payload])
      result = subject.from_payloads(payloads)

      expect(result).to eq(['test', nil])
      expect(converter).to have_received(:from_payload).with(json_payload).once
      expect(converter).to have_received(:from_payload).with(nil_payload).once
    end
  end

  describe '#from_payload_map' do
    it 'returns nil when nothing is given' do
      expect(subject.from_payload_map(nil)).to eq(nil)
    end

    it 'converts a payload hash to hash' do
      result = subject.from_payload_map({ 'one' => json_payload, 'two' => nil_payload })

      expect(result).to eq({ 'one' => 'test', 'two' => nil })
      expect(converter).to have_received(:from_payload).with(json_payload).once
      expect(converter).to have_received(:from_payload).with(nil_payload).once
    end
  end

  describe 'full circle' do
    it 'converts values to payloads and back' do
      input = ['test', nil]

      expect(subject.from_payloads(subject.to_payloads(input))).to eq(input)
    end

    it 'converts values to payloads and back' do
      input = [nil]

      expect(subject.from_payloads(subject.to_payloads(input))).to eq(input)
    end

    it 'converts values map to payloads map and back' do
      input = { 'one' => 'test', 'two' => nil }

      expect(subject.from_payload_map(subject.to_payload_map(input))).to eq(input)
    end
  end
end
