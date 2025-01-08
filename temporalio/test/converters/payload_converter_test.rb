# frozen_string_literal: true

require 'active_model'
require 'active_record'
require 'temporalio/api'
require 'temporalio/converters/payload_converter'
require 'test_base'

module Converters
  class PayloadConverterTest < TestBase
    # @type method assert_payload: (
    #   untyped input,
    #   String expected_encoding,
    #   String expected_data,
    #   ?expected_decoded_input: untyped,
    #   ?converter: Temporalio::Converters::PayloadConverter
    # ) -> untyped
    def assert_payload(
      input,
      expected_encoding,
      expected_data,
      expected_decoded_input: nil,
      converter: Temporalio::Converters::PayloadConverter.default
    )
      # Convert and check contents
      payload = converter.to_payload(input)
      assert_equal expected_encoding, payload.metadata['encoding']
      assert_equal expected_data, payload.data

      # Convert back and check
      new_input = converter.from_payload(payload)
      expected_decoded_input ||= input
      if expected_decoded_input.nil?
        assert_nil new_input
      else
        assert_equal expected_decoded_input, new_input
      end
      payload
    end

    def test_default_converter
      # Basic types
      assert_payload nil, 'binary/null', ''
      assert_payload 'test str'.encode(Encoding::ASCII_8BIT), 'binary/plain', 'test str'
      payload = assert_payload(
        Temporalio::Api::Common::V1::WorkflowExecution.new(workflow_id: 'id1'),
        'json/protobuf',
        '{"workflowId":"id1"}'
      )
      assert_equal 'temporal.api.common.v1.WorkflowExecution', payload.metadata['messageType']
      assert_payload(
        { foo: 'bar', 'baz' => 'qux' }, 'json/plain', '{"foo":"bar","baz":"qux"}',
        expected_decoded_input: { 'foo' => 'bar', 'baz' => 'qux' }
      )
      assert_payload 1234, 'json/plain', '1234'
      assert_payload 12.34, 'json/plain', '12.34'
      assert_payload true, 'json/plain', 'true'
      assert_payload false, 'json/plain', 'false'
      assert_payload ['str', nil, { 'a' => false }, 1234], 'json/plain', '["str",null,{"a":false},1234]'

      # Circular ref
      some_arr = []
      some_arr << some_arr
      assert_raises(JSON::NestingError) do
        assert_payload some_arr, 'json/plain', 'whatever'
      end

      # Time without addition is a time string (not ISO-8601)
      time = Time.now
      assert_payload time, 'json/plain', "\"#{time}\"", expected_decoded_input: time.to_s
      # Time with addition comes back as the same object (but not very useful
      # outside of Ruby)
      require 'json/add/time'
      assert_payload time, 'json/plain', time.to_json
    end

    def test_binary_proto
      # Make a new converter with all default converters except json proto so
      # that binary proto takes precedent
      converter = Temporalio::Converters::PayloadConverter::Composite.new(
        *Temporalio::Converters::PayloadConverter.default.converters.values.reject do |conv|
          conv.is_a?(Temporalio::Converters::PayloadConverter::JSONProtobuf)
        end
      )

      proto = Temporalio::Api::Common::V1::WorkflowExecution.new(workflow_id: 'id1')
      payload = assert_payload(proto, 'binary/protobuf', proto.to_proto, converter:)
      assert_equal 'temporal.api.common.v1.WorkflowExecution', payload.metadata['messageType']
    end

    # Need this support library for active model to work
    module ActiveRecordJSONSupport
      extend ActiveSupport::Concern
      include ActiveModel::Serializers::JSON

      included do
        def to_json(*args)
          hash = as_json
          hash[::JSON.create_id] = self.class.name
          hash.to_json(*args)
        end

        def self.json_create(object)
          object.delete(::JSON.create_id)
          ret = new
          ret.attributes = object
          ret
        end
      end
    end

    module ActiveModelJSONSupport
      extend ActiveSupport::Concern
      include ActiveRecordJSONSupport

      included do
        def attributes=(hash)
          hash.each do |key, value|
            send("#{key}=", value)
          end
        end

        def attributes
          instance_values
        end
      end
    end

    class MyActiveRecordObject < ActiveRecord::Base
      include ActiveRecordJSONSupport
    end

    class MyActiveModelObject
      include ActiveModel::API
      include ActiveModelJSONSupport

      attr_accessor :foo, :bar
    end

    def test_active_record_and_model
      # Make conn and schema
      ActiveRecord::Base.establish_connection(
        adapter: 'sqlite3',
        database: ':memory:'
      )
      ActiveRecord::Schema.define do
        create_table :my_active_record_objects, force: true do |t|
          t.string :foo
          t.integer :baz
        end
      end

      # Make obj
      obj = MyActiveRecordObject.new(foo: 'bar', baz: 1234)

      # Convert and check contents
      converter = Temporalio::Converters::PayloadConverter.default
      payload = converter.to_payload(obj)
      assert_equal 'json/plain', payload.metadata['encoding']
      assert_equal obj.to_json, payload.data
      # Convert back and check
      new_obj = converter.from_payload(payload)
      assert_instance_of MyActiveRecordObject, new_obj
      assert_equal obj.attributes, new_obj.attributes

      # Do the same for active model
      obj = MyActiveModelObject.new(foo: 1234, bar: 'baz')
      # Convert and check contents
      converter = Temporalio::Converters::PayloadConverter.default
      payload = converter.to_payload(obj)
      assert_equal 'json/plain', payload.metadata['encoding']
      assert_equal obj.to_json, payload.data
      # Convert back and check
      new_obj = converter.from_payload(payload)
      assert_instance_of MyActiveModelObject, new_obj
      assert_equal obj.attributes, new_obj.attributes
    end
  end
end
