require 'temporalio/interceptor/client'

module Helpers
  class TestCaptureInterceptor
    include Temporalio::Interceptor::Client

    attr_reader :called_methods

    def initialize
      @called_methods = []
      super
    end

    def start_workflow(input)
      @called_methods << :start_workflow
      super
    end

    def describe_workflow(input)
      @called_methods << :describe_workflow
      super
    end

    def query_workflow(input)
      @called_methods << :query_workflow
      super
    end

    def signal_workflow(input)
      @called_methods << :signal_workflow
      super
    end

    def cancel_workflow(input)
      @called_methods << :cancel_workflow
      super
    end

    def terminate_workflow(input)
      @called_methods << :terminate_workflow
      super
    end
  end
end
