# frozen_string_literal: true

module Temporalio
  class Worker
    # Mixin for intercepting worker work. Clases that `include` may implement their own {intercept_activity} that
    # returns their own instance of {ActivityInbound}.
    #
    # @note Input classes herein may get new required fields added and therefore the constructors of the Input classes
    #   may change in backwards incompatible ways. Users should not try to construct Input classes themselves.
    module Interceptor
      # Method called when intercepting an activity. This is called when starting an activity attempt.
      #
      # @param next_interceptor [ActivityInbound] Next interceptor in the chain that should be called. This is usually
      #   passed to {ActivityInbound} constructor.
      # @return [ActivityInbound] Interceptor to be called for activity calls.
      def intercept_activity(next_interceptor)
        next_interceptor
      end

      # Input for {ActivityInbound.execute}.
      ExecuteActivityInput = Struct.new(
        :proc,
        :args,
        :headers,
        keyword_init: true
      )

      # Input for {ActivityOutbound.heartbeat}.
      HeartbeatActivityInput = Struct.new(
        :details,
        keyword_init: true
      )

      # Inbound interceptor for intercepting inbound activity calls. This should be extended by users needing to
      # intercept activities.
      class ActivityInbound
        # @return [ActivityInbound] Next interceptor in the chain.
        attr_reader :next_interceptor

        # Initialize inbound with the next interceptor in the chain.
        #
        # @param next_interceptor [ActivityInbound] Next interceptor in the chain.
        def initialize(next_interceptor)
          @next_interceptor = next_interceptor
        end

        # Initialize the outbound interceptor. This should be extended by users to return their own {ActivityOutbound}
        # implementation that wraps the parameter here.
        #
        # @param outbound [ActivityOutbound] Next outbound interceptor in the chain.
        # @return [ActivityOutbound] Outbound activity interceptor.
        def init(outbound)
          @next_interceptor.init(outbound)
        end

        # Execute an activity and return result or raise exception. Next interceptor in chain (i.e. `super`) will
        # perform the execution.
        #
        # @param input [ExecuteActivityInput] Input information.
        # @return [Object] Activity result.
        def execute(input)
          @next_interceptor.execute(input)
        end
      end

      # Outbound interceptor for intercepting outbound activity calls. This should be extended by users needing to
      # intercept activity calls.
      class ActivityOutbound
        # @return [ActivityInbound] Next interceptor in the chain.
        attr_reader :next_interceptor

        # Initialize outbound with the next interceptor in the chain.
        #
        # @param next_interceptor [ActivityOutbound] Next interceptor in the chain.
        def initialize(next_interceptor)
          @next_interceptor = next_interceptor
        end

        # Issue a heartbeat.
        #
        # @param input [HeartbeatActivityInput] Input information.
        def heartbeat(input)
          @next_interceptor.heartbeat(input)
        end
      end
    end
  end
end
