require 'temporalio/failure_converter/basic'

module Temporalio
  module FailureConverter
    DEFAULT = Temporalio::FailureConverter::Basic.new
  end
end
