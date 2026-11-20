# frozen_string_literal: true

require 'base64'
require 'base64_codec'
require 'in_memory_storage_driver'
require 'temporalio/api'
require 'temporalio/converters/data_converter'
require 'temporalio/converters/payload_codec'
require 'temporalio/testing'
require 'test'

module Converters
  class DataConverterTest < Test
    def test_inline_payloads_are_not_rewrapped_with_or_without_storage
      driver = InMemoryStorageDriver.new
      storage = Temporalio::Converters::ExternalStorage.new(drivers: [driver])
      [nil, storage].each do |external_storage|
        payload_converter = Temporalio::Converters::PayloadConverter.default.dup
        received = []
        payload_converter.define_singleton_method(:from_payloads) do |payloads, hints: nil|
          received << payloads
          super(payloads, hints:)
        end
        converter = Temporalio::Converters::DataConverter.new(payload_converter:, external_storage:)
        payloads = converter.to_payloads(['abc', 123])

        assert_equal ['abc', 123], converter.from_payloads(payloads)
        # Value equality misses a new container whose native arena is retained by the original payloads.
        assert_same payloads, received.fetch(0)
      end
      assert_empty driver.retrieve_calls
    end

    def test_retrieval_preserves_the_original_reference_container
      converter = Temporalio::Converters::DataConverter.new(
        external_storage: Temporalio::Converters::ExternalStorage.new(
          drivers: [InMemoryStorageDriver.new], payload_size_threshold: 0
        )
      )
      reference = converter.to_payload('stored')
      inline = converter.payload_converter.to_payload('inline')
      payloads = Temporalio::Api::Common::V1::Payloads.new(payloads: [inline, reference])
      original_wire = payloads.to_proto

      assert_equal 'stored', converter.from_payload(reference)
      assert_equal %w[inline stored], converter.from_payloads(payloads)
      assert_equal original_wire, payloads.to_proto
    end

    def test_without_storage_rejects_references_before_conversion
      converter = Temporalio::Converters::DataConverter.new
      reference = Temporalio::Internal::ExternalStorageReferences.create_reference_payload(
        driver_name: 'mem', claim_data: { 'key' => 'k' }, original_size_bytes: 1
      )
      payloads = Temporalio::Api::Common::V1::Payloads.new(
        payloads: [converter.to_payload('ordinary'), reference]
      )

      assert_raises(Temporalio::Error::ExternalStorageNotConfiguredError) do
        converter.from_payload(reference, hint: Temporalio::Converters::RawValue)
      end
      assert_raises(Temporalio::Error::ExternalStorageNotConfiguredError) do
        converter.from_payloads(payloads, hints: [String, Temporalio::Converters::RawValue])
      end
    end

    def test_with_codec
      converter = Temporalio::Converters::DataConverter.new(
        failure_converter: Temporalio::Converters::FailureConverter.new(encode_common_attributes: true),
        payload_codec: Base64Codec.new
      )

      # Single payload
      payload = converter.to_payload('abc')
      assert_equal 'test/base64', payload.metadata['encoding']
      assert_equal 'abc', converter.from_payload(payload)

      # Multi-payload
      payloads = converter.to_payloads(['abc', 123])
      assert_equal(['test/base64', 'test/base64'], payloads.payloads.map { |p| p.metadata['encoding'] })
      assert_equal ['abc', 123], converter.from_payloads(payloads)

      # Failure
      failure = converter.to_failure(Temporalio::Error._with_backtrace_and_cause(
                                       Temporalio::Error::ApplicationError.new('outer', { foo: 'bar' }),
                                       backtrace: %w[stack-val-1 stack-val-2],
                                       cause: Temporalio::Error::ApplicationError.new('inner', { baz: 123 })
                                     ))
      assert_equal 'Encoded failure', failure.message
      assert_equal '', failure.stack_trace
      assert_equal 'test/base64', failure.encoded_attributes.metadata['encoding']
      assert_equal 'test/base64', failure.application_failure_info.details.payloads.first.metadata['encoding']
      assert_equal 'Encoded failure', failure.cause.message
      assert_equal '', failure.cause.stack_trace
      assert_equal 'test/base64', failure.cause.encoded_attributes.metadata['encoding']
      assert_equal 'test/base64', failure.cause.application_failure_info.details.payloads.first.metadata['encoding']
      error = converter.from_failure(failure)
      assert_instance_of Temporalio::Error::ApplicationError, error
      assert_equal 'outer', error.message
      assert_equal %w[stack-val-1 stack-val-2], error.backtrace
      assert_equal 'bar', error.details.first['foo'] # steep:ignore
      assert_instance_of Temporalio::Error::ApplicationError, error.cause
      assert_equal 'inner', error.cause&.message
      assert_equal [], error.cause&.backtrace
      assert_equal 123, error.cause.details.first['baz'] # steep:ignore
    end
  end
end
