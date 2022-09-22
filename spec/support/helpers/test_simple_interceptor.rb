require 'temporal/interceptor/client'

module Helpers
  class TestSimpleInterceptor < Temporal::Interceptor::Client
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
