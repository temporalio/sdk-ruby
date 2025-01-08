# frozen_string_literal: true

require 'base64_codec'
require 'temporalio/api'
require 'temporalio/converters/data_converter'
require 'temporalio/converters/payload_codec'
require 'temporalio/testing'
require 'test_base'

module Converters
  class DataConverterTest < TestBase
    def test_with_codec
      converter = Temporalio::Converters::DataConverter.new(
        failure_converter: Ractor.make_shareable(
          Temporalio::Converters::FailureConverter.new(encode_common_attributes: true)
        ),
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
