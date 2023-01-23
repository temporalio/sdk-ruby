require 'temporalio/interceptor/activity_inbound'
require 'temporalio/interceptor/activity_outbound'
require 'temporalio/interceptor/client'

module Helpers
  class TestCaptureInterceptor
    include Temporalio::Interceptor::Client
    include Temporalio::Interceptor::ActivityInbound
    include Temporalio::Interceptor::ActivityOutbound

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

    def execute_activity(input)
      @called_methods << :execute_activity
      super
    end

    def info
      @called_methods << :info
      super
    end

    def heartbeat(*details)
      @called_methods << :heartbeat
      super
    end
  end
end
