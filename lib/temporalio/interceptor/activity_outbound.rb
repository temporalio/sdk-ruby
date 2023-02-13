module Temporalio
  module Interceptor
    # A mixin for implementing outbound Activity interceptors.
    module ActivityOutbound
      # Interceptor for {Temporalio::Activity::Context#info}.
      #
      # @yieldreturn Temporalio::Activity::Info
      #
      # @return [Temporalio::Activity::Info]
      def activity_info
        yield
      end

      # Interceptor for {Temporalio::Activity::Context#heartbeat}.
      #
      # @yieldparam Array[untyped]
      #
      # @param details [any] A list of details supplied with the heartbeat.
      def heartbeat(*details)
        yield(*details)
      end
    end
  end
end
