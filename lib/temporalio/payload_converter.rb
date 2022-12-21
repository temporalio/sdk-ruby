require 'temporalio/payload_converter/bytes'
require 'temporalio/payload_converter/composite'
require 'temporalio/payload_converter/json'
require 'temporalio/payload_converter/nil'

module Temporalio
  module PayloadConverter
    DEFAULT = Temporalio::PayloadConverter::Composite.new(
      Temporalio::PayloadConverter::Nil.new,
      Temporalio::PayloadConverter::Bytes.new,
      Temporalio::PayloadConverter::JSON.new,
    )
  end
end
