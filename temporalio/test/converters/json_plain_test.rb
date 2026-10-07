# frozen_string_literal: true

require 'temporalio/converters/payload_converter/json_plain'
require 'test'

module Converters
  class JSONPlainTest < Test
    class Addition
      attr_reader :value

      def self.json_create(object)
        new(object.fetch('value'))
      end

      def initialize(value)
        @value = value
      end

      def to_json(*args)
        { 'json_class' => self.class.name, 'value' => value }.to_json(*args) # steep:ignore
      end
    end

    class NonCreatableAddition < Addition
      def self.json_creatable?
        false
      end
    end

    def test_json2_time_addition
      skip 'JSON 3 requires a converter-local Time serialization adapter' if JSON::VERSION.to_i >= 3

      converter = Temporalio::Converters::PayloadConverter::JSONPlain.new
      time = Time.now
      encoded = converter.to_payload(time) || raise
      assert_equal 'json/plain', encoded.metadata['encoding']
      assert_equal "\"#{time}\"", encoded.data
      assert_equal time.to_s, converter.from_payload(encoded)

      require 'json/add/time'
      encoded = converter.to_payload(time) || raise
      assert_equal 'json/plain', encoded.metadata['encoding']
      assert_equal time.to_json, encoded.data
      assert_equal time, converter.from_payload(encoded)
    end

    def test_nested_legacy_additions
      json = '{"json_class":"Converters::JSONPlainTest::Addition",' \
             '"value":[{"json_class":"Converters::JSONPlainTest::Addition","value":123}]}'
      converter = Temporalio::Converters::PayloadConverter::JSONPlain.new
      value = converter.from_payload(payload(json)) #: untyped
      assert_instance_of Addition, value
      assert_instance_of Addition, value.value.first
      assert_equal 123, value.value.first.value
      assert_equal json, converter.to_payload(value).data
    end

    def test_additions_disabled_or_omitted
      json = '{"json_class":"Converters::JSONPlainTest::Addition","value":123}'
      [{}, { create_additions: false }].each do |parse_options|
        converter = Temporalio::Converters::PayloadConverter::JSONPlain.new(parse_options:)
        assert_equal({ 'json_class' => Addition.name, 'value' => 123 }, converter.from_payload(payload(json)))
      end
    end

    def test_non_creatable_classes
      converter = Temporalio::Converters::PayloadConverter::JSONPlain.new
      [Object.name, NonCreatableAddition.name].each do |name|
        json = "{\"json_class\":\"#{name}\",\"value\":123}"
        assert_equal({ 'json_class' => name, 'value' => 123 }, converter.from_payload(payload(json)))
      end
    end

    def test_missing_class
      converter = Temporalio::Converters::PayloadConverter::JSONPlain.new
      assert_raises(ArgumentError) do
        converter.from_payload(payload('{"json_class":"MissingJSONAddition"}'))
      end
    end

    def test_callback_after_additions
      version = Gem::Version.new(JSON::VERSION)
      skip 'Callback adapters are tested on JSON 2.18 and newer' if version < Gem::Version.new('2.18.0')

      options = { create_additions: true, on_load: lambda { |object|
        object.is_a?(Addition) ? object.value : object
      } }.freeze
      converter = Temporalio::Converters::PayloadConverter::JSONPlain.new(parse_options: options)
      assert_equal [123], converter.from_payload(payload('[{"json_class":"Converters::JSONPlainTest::Addition",' \
                                                         '"value":123}]'))
    end

    private

    def payload(json)
      Temporalio::Api::Common::V1::Payload.new(metadata: { 'encoding' => 'json/plain' }, data: json)
    end
  end
end
