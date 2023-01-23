require 'temporalio/interceptor/client'
require 'temporalio/interceptor/activity_outbound'

module Helpers
  class TestSimpleInterceptor
    include Temporalio::Interceptor::Client
    include Temporalio::Interceptor::ActivityOutbound

    def initialize(name)
      @name = name
      super()
    end

    def start_workflow(input)
      input << "before_#{@name}"
      result = yield(input)
      result << "after_#{@name}"
      result
    end

    def info
      info = yield
      info.heartbeat_details << @name
      info
    end
  end
end
