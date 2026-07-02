# typed: true

class Temporalio::Converters::PayloadConverter::JSONPlain < ::Temporalio::Converters::PayloadConverter::Encoding
  extend T::Sig

  ENCODING = T.let(T.unsafe(nil), String)

  sig { params(parse_options: T::Hash[Symbol, Object], generate_options: T::Hash[Symbol, Object]).void }
  def initialize(parse_options: T.unsafe(nil), generate_options: T.unsafe(nil)); end
end
