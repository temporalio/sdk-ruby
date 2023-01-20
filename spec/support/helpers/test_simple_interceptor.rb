require 'temporalio/interceptor/client'

module Helpers
  class TestSimpleInterceptor
    include Temporalio::Interceptor::Client

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
  end
end
