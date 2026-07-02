# typed: true

class Temporalio::Converters::PayloadConverter::BinaryPlain < ::Temporalio::Converters::PayloadConverter::Encoding
  ENCODING = T.let(T.unsafe(nil), String)
end
