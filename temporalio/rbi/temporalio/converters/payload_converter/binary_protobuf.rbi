# typed: true

class Temporalio::Converters::PayloadConverter::BinaryProtobuf < ::Temporalio::Converters::PayloadConverter::Encoding
  ENCODING = T.let(T.unsafe(nil), String)
end
