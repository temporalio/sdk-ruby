# typed: true

class Temporalio::Converters::PayloadConverter::BinaryNull < ::Temporalio::Converters::PayloadConverter::Encoding
  ENCODING = T.let(T.unsafe(nil), String)
end
