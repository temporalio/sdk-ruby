# frozen_string_literal: true

require 'json'
require 'temporalio/api'
require 'temporalio/converters/payload_converter/encoding'
require 'temporalio/workflow'

module Temporalio
  module Converters
    class PayloadConverter
      # Encoding for all values for +json/plain+ encoding.
      class JSONPlain < Encoding
        ENCODING = 'json/plain'

        # Create JSONPlain converter.
        #
        # @param parse_options [Hash] Options for {::JSON.parse}. If using json >3, this converter supports
        #   +create_additions+ through parser callbacks so existing +json_class+ payloads can still be restored.
        # @param generate_options [Hash] Options for {::JSON.generate}.
        def initialize(parse_options: { create_additions: true }, generate_options: {})
          super()
          @parse_options = parse_options
          @generate_options = generate_options
        end

        # (see Encoding.encoding)
        def encoding
          ENCODING
        end

        # (see Encoding.to_payload)
        def to_payload(value, hint: nil) # rubocop:disable Lint/UnusedMethodArgument
          # For generate and parse, if we are in a workflow, we need to do this outside of the durable scheduler since
          # some things like the recent https://github.com/ruby/json/pull/832 may make illegal File.expand_path calls.
          # And other future things may be slightly illegal in JSON generate/parse and we don't want to break everyone
          # when it happens.
          data = if Temporalio::Workflow.in_workflow?
                   Temporalio::Workflow::Unsafe.durable_scheduler_disabled do
                     JSON.generate(value, @generate_options).b
                   end
                 else
                   JSON.generate(value, @generate_options).b
                 end

          Api::Common::V1::Payload.new(metadata: { 'encoding' => ENCODING }, data:)
        end

        # (see Encoding.from_payload)
        def from_payload(payload, hint: nil) # rubocop:disable Lint/UnusedMethodArgument
          parse_options = JSON::VERSION.to_i >= 3 ? json3_parse_options : @parse_options
          # See comment in to_payload about why we have to do something different in workflow
          if Temporalio::Workflow.in_workflow?
            Temporalio::Workflow::Unsafe.durable_scheduler_disabled do
              JSON.parse(payload.data, **parse_options)
            end
          else
            JSON.parse(payload.data, **parse_options)
          end
        end

        private

        def json3_parse_options
          options = @parse_options.dup
          return options unless options.delete(:create_additions)

          on_load = options[:on_load]
          options[:on_load] = lambda do |object|
            if object.is_a?(Hash) && (class_path = object['json_class'])
              klass = begin
                Object.const_get(class_path)
              rescue NameError => e
                raise ArgumentError, "can't get const #{class_path}: #{e}"
              end
              if klass.respond_to?(:json_creatable?) ? klass.json_creatable? : klass.respond_to?(:json_create)
                object = klass.json_create(object)
              end
            end
            on_load.nil? ? object : on_load.call(object)
          end
          options
        end
      end
    end
  end
end
