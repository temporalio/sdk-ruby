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
        # @param parse_options [Hash] Options for {::JSON.parse}.
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
          # See comment in to_payload about why we have to do something different in workflow
          if Temporalio::Workflow.in_workflow?
            Temporalio::Workflow::Unsafe.durable_scheduler_disabled do
              JSON.parse(payload.data, @parse_options)
            end
          else
            JSON.parse(payload.data, @parse_options)
          end
        end
      end
    end
  end
end
