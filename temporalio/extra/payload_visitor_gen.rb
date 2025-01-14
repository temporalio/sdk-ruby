# frozen_string_literal: true

require_relative '../lib/temporalio/api'
require_relative '../lib/temporalio/api/cloud/cloudservice/v1/service'
require_relative '../lib/temporalio/api/operatorservice/v1/service'
require_relative '../lib/temporalio/api/workflowservice/v1/service'
require_relative '../lib/temporalio/internal/bridge/api'

# Generator for the payload visitor.
class PayloadVisitorGen
  DESCRIPTORS = [
    'temporal.api.workflowservice.v1.WorkflowService',
    'temporal.api.operatorservice.v1.OperatorService',
    'temporal.api.cloud.cloudservice.v1.CloudService',
    'temporal.api.export.v1.WorkflowExecutions',
    'coresdk.workflow_activation.WorkflowActivation',
    'coresdk.workflow_completion.WorkflowActivationCompletion'
  ].freeze

  # Generate file code.
  #
  # @return [String] File code.
  def gen_file_code
    # Collect all the methods of all the classes
    methods = {}
    DESCRIPTORS.each do |name|
      desc = Google::Protobuf::DescriptorPool.generated_pool.lookup(name) or raise "Unknown name: #{name}"
      walk_desc(desc:, methods:)
    end

    # Build the code for each method
    method_bodies = methods.map do |_, method_hash|
      # Do nothing if no fields
      next if method_hash[:fields].empty?

      body = "def #{method_name_from_desc(method_hash[:desc])}(value)\n"
      # Ignore if search attributes are ignored
      if method_hash[:desc].name == 'temporal.api.common.v1.SearchAttributes'
        body += "  return if @skip_search_attributes\n"
      end
      body += "  @on_enter&.call(value)\n"
      method_hash[:fields].each do |field_hash|
        field_name = field_hash[:field].name
        other_method_name = method_name_from_desc(field_hash[:type])
        body += case field_hash[:form]
                when :map
                  # We need to skip this if skip search attributes is on and the field name is search attributes. This
                  # is because Core protos do not always use the search attribute type.
                  suffix = field_name == 'search_attributes' ? ' unless @skip_search_attributes' : ''
                  "  value.#{field_name}.values.each { |v| #{other_method_name}(v) }#{suffix}\n"
                when :repeated_payload
                  "  api_common_v1_payload_repeated(value.#{field_name}) unless value.#{field_name}.empty?\n"
                when :repeated
                  "  value.#{field_name}.each { |v| #{other_method_name}(v) }\n"
                else
                  "  #{other_method_name}(value.#{field_name}) if value.has_#{field_name}?\n"
                end
      end
      "#{body}  @on_exit&.call(value)\nend"
    end.compact.sort

    # Build the class
    <<~TEXT
      # frozen_string_literal: true

      # Generated code.  DO NOT EDIT!

      require 'temporalio/api'
      require 'temporalio/internal/bridge/api'

      module Temporalio
        module Api
          # Visitor for payloads within the protobuf structure. This visitor is thread safe and can be used multiple
          # times since it stores no mutable state.
          #
          # @note WARNING: This class is not considered stable for external use and may change as needed for internal
          #   reasons.
          class PayloadVisitor
            # Create a new visitor, calling the block on every {Common::V1::Payload} or
            # {Google::Protobuf::RepeatedField<Payload>} encountered.
            #
            # @param on_enter [Proc, nil] Proc called at the beginning of the processing for every protobuf value
            #   _except_ the ones calling the block.
            # @param on_exit [Proc, nil] Proc called at the end of the processing for every protobuf value _except_ the
            #   ones calling the block.
            # @param skip_search_attributes [Boolean] If true, payloads within search attributes do not call the block.
            # @param traverse_any [Boolean] If true, when a [Google::Protobuf::Any] is encountered, it is unpacked,
            #   visited, then repacked.
            # @yield [value] Block called with the visited payload value.
            # @yieldparam [Common::V1::Payload, Google::Protobuf::RepeatedField<Payload>] Payload or payload list.
            def initialize(
              on_enter: nil,
              on_exit: nil,
              skip_search_attributes: false,
              traverse_any: false,
              &block
            )
              raise ArgumentError, 'Block required' unless block_given?
              @on_enter = on_enter
              @on_exit = on_exit
              @skip_search_attributes = skip_search_attributes
              @traverse_any = traverse_any
              @block = block
            end

            # Visit the given protobuf message.
            #
            # @param value [Google::Protobuf::Message] Message to visit.
            def run(value)
              return unless value.is_a?(Google::Protobuf::MessageExts)
              method_name = method_name_from_proto_name(value.class.descriptor.name)
              send(method_name, value) if respond_to?(method_name, true)
              nil
            end

            # @!visibility private
            def _run_activation(value)
              coresdk_workflow_activation_workflow_activation(value)
            end

            # @!visibility private
            def _run_activation_completion(value)
              coresdk_workflow_completion_workflow_activation_completion(value)
            end

            private

            def method_name_from_proto_name(name)
              name
                  .sub('temporal.api.', 'api_')
                  .gsub('.', '_')
                  .gsub(/([a-z])([A-Z])/, '\\1_\\2')
                  .downcase
            end

            def api_common_v1_payload(value)
              @block.call(value)
            end

            def api_common_v1_payload_repeated(value)
              @block.call(value)
            end

            def google_protobuf_any(value)
              return unless @traverse_any
              desc = Google::Protobuf::DescriptorPool.generated_pool.lookup(value.type_name)
              unpacked = value.unpack(desc.msgclass)
              run(unpacked)
              value.pack(unpacked)
            end

            ### Generated method bodies below ###

            #{method_bodies.join("\n\n").gsub("\n", "\n      ")}
          end
        end
      end
    TEXT
  end

  private

  def walk_desc(desc:, methods:)
    case desc
    when Google::Protobuf::ServiceDescriptor
      walk_service_desc(desc:, methods:)
    when Google::Protobuf::Descriptor
      walk_message_desc(desc:, methods:)
    when Google::Protobuf::EnumDescriptor
      # Ignore
    else
      raise "Unrecognized descriptor: #{desc}"
    end
  end

  def walk_service_desc(desc:, methods:)
    desc.each do |method|
      walk_desc(desc: method.input_type, methods:)
      walk_desc(desc: method.output_type, methods:)
    end
  end

  def walk_message_desc(desc:, methods:)
    return if methods[desc.name]

    methods[desc.name] = {
      desc:,
      fields: desc.map do |field|
        next unless field.subtype && desc_has_payloads_or_any(field.subtype)

        {
          field:,
          type: if field.subtype.options.map_entry
                  field.subtype.lookup('value').subtype
                else
                  field.subtype
                end,
          form: if field.subtype.options.map_entry
                  :map
                elsif field.label == :repeated && field.subtype.msgclass == Temporalio::Api::Common::V1::Payload
                  :repeated_payload
                elsif field.label == :repeated
                  :repeated
                else
                  :message
                end
        }
      end.compact
    }

    desc.each do |field|
      type = field.subtype
      # If the subtype is a map entry, only walk the value of the subtype
      type = type.lookup('value').subtype if type.is_a?(Google::Protobuf::Descriptor) && type.options.map_entry
      walk_desc(desc: type, methods:) if type.is_a?(Google::Protobuf::Descriptor)
    end
  end

  def desc_has_payloads_or_any(desc, parents: [])
    return false if !desc.is_a?(Google::Protobuf::Descriptor) || parents.include?(desc)

    desc.msgclass == Temporalio::Api::Common::V1::Payload ||
      desc.msgclass == Google::Protobuf::Any ||
      desc.any? do |field|
        field.subtype && desc_has_payloads_or_any(field.subtype, parents: parents + [desc])
      end
  end

  def method_name_from_desc(desc)
    desc.name
        .sub('temporal.api.', 'api_')
        .gsub('.', '_')
        .gsub(/([a-z])([A-Z])/, '\1_\2')
        .downcase
  end
end
