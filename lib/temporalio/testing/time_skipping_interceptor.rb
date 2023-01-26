require 'temporalio/interceptor/client'
require 'temporalio/testing/time_skipping_handle'

module Temporalio
  module Testing
    class TimeSkippingInterceptor
      include Temporalio::Interceptor::Client

      def initialize(env)
        @env = env
      end

      def start_workflow(input)
        handle = yield(input)
        Temporalio::Testing::TimeSkippingHandle.new(handle, env)
      end

      private

      attr_reader :env
    end
  end
end
