module Temporalio
  module Interceptor
    # A mixin for implementing outbound Activity interceptors.
    module ActivityOutbound
      # Interceptor for {Temporalio::Activity::Context#info}.
      #
      # @return [Temporalio::Activity::Info]
      def info
        yield
      end

      # Interceptor for {Temporalio::Activity::Context#heartbeat}.
      #
      # @param details [any] A list of details supplied with the heartbeat.
      def heartbeat(*details)
        yield(*details)
      end
    end
  end
end
