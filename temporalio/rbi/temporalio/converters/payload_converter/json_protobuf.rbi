# typed: true

class Temporalio::Converters::PayloadConverter::JSONProtobuf < ::Temporalio::Converters::PayloadConverter::Encoding
  ENCODING = T.let(T.unsafe(nil), String)
end
