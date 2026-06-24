# frozen_string_literal: true

require 'test'
require 'tmpdir'

require_relative '../extra/proto_gen'

class ProtoGenTest < Test
  def test_normalize_generated_rbs_preserves_repeated_enum_iteration_type
    content = <<~RBS
      module Example
        class Message
          attr_accessor enum_values(): ::Google::Protobuf::RepeatedField[::Example::SomeEnum::names | ::Integer, ::Example::SomeEnum::strings | ::Integer, ::Example::SomeEnum]
          attr_accessor child_messages(): ::Google::Protobuf::RepeatedField[::Example::ChildMessage, ::Example::ChildMessage]
        end
      end
    RBS

    normalized_content = normalize_rbs(content)

    assert_includes normalized_content,
                    'attr_accessor enum_values(): (::Google::Protobuf::RepeatedField & ' \
                    '::Google::Protobuf::_RepeatedEnumField[::Example::SomeEnum::names | ::Integer])'
    assert_includes normalized_content,
                    'attr_accessor child_messages(): ::Google::Protobuf::RepeatedField'
  end

  private

  def normalize_rbs(content)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'example_pb.rbs')
      File.write(path, content)

      ProtoGen.new.send(:normalize_generated_rbs!, path)

      File.read(File.join(dir, 'example.rbs'))
    end
  end
end
