require 'temporal/payload_converter/bytes'
require 'temporal/payload_converter/composite'
require 'temporal/payload_converter/json'
require 'temporal/payload_converter/nil'

module Temporal
  module PayloadConverter
    DEFAULT = Temporal::PayloadConverter::Composite.new(
      Temporal::PayloadConverter::Nil.new,
      Temporal::PayloadConverter::Bytes.new,
      Temporal::PayloadConverter::JSON.new,
    )
  end
end
