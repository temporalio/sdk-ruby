module Temporalio
  module Interceptor
    # A mixin for implementing inbound Activity interceptors.
    module ActivityInbound
      class ExecuteActivityInput < Struct.new(
        :activity,
        :args,
        :headers,
        keyword_init: true,
      ); end

      # Interceptor for {Temporalio::Activity#execute}.
      #
      # @param input [ExecuteActivityInput]
      def execute_activity(input)
        yield(input)
      end
    end
  end
end
