require 'temporal/api/common/v1/message_pb'
require 'temporal/data_converter'
require 'temporal/error/failure'
require 'temporal/failure_converter'
require 'temporal/payload_converter'
require 'temporal/payload_codec/base'

class TestConcatenatingPayloadCodec < Temporal::PayloadCodec::Base
  ENCODING = 'mixed'.freeze

  def initialize(separator)
    super()
    @separator = separator
  end

  def encode(payloads)
    data = payloads.map do |payload|
      Temporal::Api::Common::V1::Payload.encode(payload)
    end.join(separator)

    return [] if data.empty?

    [Temporal::Api::Common::V1::Payload.new(
      metadata: { encoding: ENCODING },
      data: data
    )]
  end

  def decode(payloads)
    return if payloads.empty?
    raise 'unexpected number of payloads' if payloads.length > 1

    payloads.first.data.split(separator).map do |bytes|
      Temporal::Api::Common::V1::Payload.decode(bytes)
    end
  end

  private

  attr_reader :separator
end

class TestFaultyPayloadCodec < Temporal::PayloadCodec::Base
  def encode(_payloads)
    []
  end

  def decode(_payloads)
    []
  end
end

# This codec doesn't do much, but it ensures that codecs are applied in the correct order
class TestEncodingSwappingPayloadCodec < Temporal::PayloadCodec::Base
  FROM_ENCODING = TestConcatenatingPayloadCodec::ENCODING
  TO_ENCODING = 'swapped'.freeze

  def encode(payloads)
    payload = payloads.first
    raise 'unexpected payload' unless payload.metadata['encoding'] == FROM_ENCODING

    payload.metadata['encoding'] = TO_ENCODING
    [payload]
  end

  def decode(payloads)
    payload = payloads.first
    raise 'unexpected payload' unless payload.metadata['encoding'] == TO_ENCODING

    payload.metadata['encoding'] = FROM_ENCODING
    [payload]
  end
end

describe Temporal::DataConverter do
  subject do
    described_class.new(
      payload_converter: converter,
      payload_codecs: codecs,
      failure_converter: failure_converter,
    )
  end
  let(:converter) { Temporal::PayloadConverter::DEFAULT }
  let(:codecs) { [] }
  let(:failure_converter) { Temporal::FailureConverter::DEFAULT }
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
  let(:test_codec) { TestConcatenatingPayloadCodec.new('$$$') }
  let(:faulty_codec) { TestFaultyPayloadCodec.new }
  let(:swap_codec) { TestEncodingSwappingPayloadCodec.new }

  before do
    allow(converter).to receive(:to_payload).and_call_original
    allow(converter).to receive(:from_payload).and_call_original
    allow(test_codec).to receive(:encode).and_call_original
    allow(test_codec).to receive(:decode).and_call_original
    allow(failure_converter).to receive(:to_failure).and_call_original
    allow(failure_converter).to receive(:from_failure).and_call_original
  end

  describe '#to_payload' do
    it 'calls the provided payload converter' do
      result = subject.to_payload('test')

      expect(result).to be_a(Temporal::Api::Common::V1::Payload)
      expect(converter).to have_received(:to_payload).with('test')
    end
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

    context 'with payload codecs' do
      let(:codecs) { [test_codec] }

      it 'encodes the payloads' do
        result = subject.to_payloads(['test', nil])

        expect(result).to be_a(Temporal::Api::Common::V1::Payloads)
        expect(result.payloads.length).to eq(1)
        expect(result.payloads.first.metadata['encoding'])
          .to eq(TestConcatenatingPayloadCodec::ENCODING)

        expect(test_codec).to have_received(:encode).once
      end
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

    context 'with payload codecs' do
      let(:codecs) { [test_codec] }

      it 'encodes each payload' do
        result = subject.to_payload_map({ 'one' => 'test', 'two' => nil })

        expect(result.length).to eq(2)
        expect(result['one'].metadata['encoding']).to eq(TestConcatenatingPayloadCodec::ENCODING)
        expect(result['two'].metadata['encoding']).to eq(TestConcatenatingPayloadCodec::ENCODING)

        expect(test_codec).to have_received(:encode).twice
      end
    end

    context 'with a faulty codec' do
      let(:codecs) { [test_codec, faulty_codec] }

      it 'raises an error' do
        expect do
          subject.to_payload_map({ 'one' => 'test', 'two' => nil })
        end.to raise_error(described_class::MissingPayload, 'Payload Codecs returned no payloads')
      end
    end
  end

  describe '#to_failure' do
    let(:error) do
      Temporal::Error::ApplicationError.new('test error', type: 'test type', details: 'test')
    end

    it 'converts an error to a failure' do
      result = subject.to_failure(error)

      expect(result).to be_a(Temporal::Api::Failure::V1::Failure)
      expect(result.message).to eq('test error')
      expect(result.application_failure_info.type).to eq('test type')
      expect(result.application_failure_info.details.payloads.first.data).to eq('"test"')

      expect(failure_converter).to have_received(:to_failure).with(error, converter).once
    end

    context 'with payload codecs' do
      let(:codecs) { [test_codec] }

      it 'encodes payloads' do
        result = subject.to_failure(error)
        payloads = result.application_failure_info.details.payloads

        expect(payloads.length).to eq(1)
        expect(payloads.first.metadata['encoding']).to eq(TestConcatenatingPayloadCodec::ENCODING)

        expect(test_codec).to have_received(:encode).once
      end
    end
  end

  describe '#from_payload' do
    it 'calls the provided payload converter' do
      result = subject.from_payload(json_payload)

      expect(result).to eq('test')
      expect(converter).to have_received(:from_payload).with(json_payload)
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

    context 'with payload codecs' do
      let(:codecs) { [test_codec] }

      it 'decodecs the payloads' do
        mixed_payloads = test_codec.encode([json_payload, nil_payload])
        payloads = Temporal::Api::Common::V1::Payloads.new(payloads: mixed_payloads)

        result = subject.from_payloads(payloads)

        expect(result).to eq(['test', nil])
        expect(test_codec).to have_received(:decode).once
      end
    end
  end

  describe '#from_payload_map' do
    let(:json_encoded) { test_codec.encode([json_payload]).first }
    let(:nil_encoded) { test_codec.encode([nil_payload]).first }

    it 'returns nil when nothing is given' do
      expect(subject.from_payload_map(nil)).to eq(nil)
    end

    it 'converts a payload hash to hash' do
      result = subject.from_payload_map({ 'one' => json_payload, 'two' => nil_payload })

      expect(result).to eq({ 'one' => 'test', 'two' => nil })
      expect(converter).to have_received(:from_payload).with(json_payload).once
      expect(converter).to have_received(:from_payload).with(nil_payload).once
    end

    context 'with payload codecs' do
      let(:codecs) { [test_codec] }

      it 'decodecs each payload' do
        result = subject.from_payload_map({ 'one' => json_encoded, 'two' => nil_encoded })

        expect(result).to eq({ 'one' => 'test', 'two' => nil })
        expect(test_codec).to have_received(:decode).twice
      end
    end

    context 'with a faulty codec' do
      let(:codecs) { [faulty_codec, test_codec] }

      it 'raises an error' do
        expect do
          subject.from_payload_map({ 'one' => json_encoded, 'two' => nil_encoded })
        end.to raise_error(described_class::MissingPayload, 'Payload Codecs returned no payloads')
      end
    end
  end

  describe '#from_failure' do
    let(:failure) do
      Temporal::Api::Failure::V1::Failure.new(
        message: 'Test failure',
        stack_trace: "a.rb:1\nb.rb:2",
        application_failure_info: Temporal::Api::Failure::V1::ApplicationFailureInfo.new(
          type: 'Test application error',
          non_retryable: true,
          details: { payloads: [payload] },
        ),
      )
    end
    let(:payload) { json_payload }

    it 'converts a failure to an error' do
      result = subject.from_failure(failure)

      expect(result).to be_a(Temporal::Error::ApplicationError)
      expect(result.message).to eq('Test failure')
      expect(result.type).to eq('Test application error')
      expect(result).not_to be_retryable
      expect(result.details).to eq(['test'])
      expect(result.backtrace).to eq(['a.rb:1', 'b.rb:2'])

      expect(failure_converter).to have_received(:from_failure).with(failure, converter).once
    end

    context 'with payload codecs' do
      let(:codecs) { [test_codec] }
      let(:payload) { test_codec.encode([json_payload]).first }

      it 'decodecs each payload' do
        result = subject.from_failure(failure)

        expect(result).to be_a(Temporal::Error::ApplicationError)
        expect(result.details).to eq(['test'])

        expect(test_codec).to have_received(:decode).once
      end
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

    it 'converts an error to a failure and back' do
      error = Temporal::Error::ApplicationError.new(
        'test error',
        type: 'test type',
        details: 'test'
      )

      expect(subject.from_failure(subject.to_failure(error))).to eq(error)
    end

    context 'with payload codecs' do
      let(:codecs) { [test_codec, swap_codec] }

      it 'converts values to payloads and back' do
        input = ['test', nil]

        expect(subject.from_payloads(subject.to_payloads(input))).to eq(input)
      end

      it 'converts values map to payloads map and back' do
        input = { 'one' => 'test', 'two' => nil }

        expect(subject.from_payload_map(subject.to_payload_map(input))).to eq(input)
      end

      it 'converts an error to a failure and back' do
        error = Temporal::Error::ApplicationError.new(
          'test error',
          type: 'test type',
          details: 'test'
        )

        expect(subject.from_failure(subject.to_failure(error))).to eq(error)
      end
    end
  end
end
