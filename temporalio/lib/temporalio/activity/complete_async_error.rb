# frozen_string_literal: true

require 'temporalio/error'

module Temporalio
  module Activity
    # Error raised inside an activity to mark that the activity will be completed asynchronously.
    class CompleteAsyncError < Error
    end
  end
end
