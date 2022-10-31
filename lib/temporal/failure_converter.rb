require 'temporal/failure_converter/basic'
require 'temporal/payload_converter'

module Temporal
  module FailureConverter
    DEFAULT = Temporal::FailureConverter::Basic.new
  end
end
