# frozen_string_literal: true

module Temporalio
  class Worker
    # Base class for poller behaviors that control how polling scales.
    class PollerBehavior
      # @!visibility private
      def _to_bridge_options
        raise NotImplementedError, 'Subclasses must implement this method'
      end

      # A poller behavior that attempts to poll as long as a slot is available, up to the
      # provided maximum. Cannot be less than two for workflow tasks, or one for other tasks.
      class SimpleMaximum < PollerBehavior
        # @return [Integer] Maximum number of concurrent poll requests.
        attr_reader :maximum

        # @param maximum [Integer] Maximum number of concurrent poll requests.
        def initialize(maximum)
          super()
          @maximum = maximum
        end

        # @!visibility private
        def _to_bridge_options
          Internal::Bridge::Worker::PollerBehaviorSimpleMaximum.new(simple_maximum: @maximum)
        end
      end

      # A poller behavior that automatically scales the number of pollers based on feedback
      # from the server. A slot must be available before beginning polling.
      class Autoscaling < PollerBehavior
        # @return [Integer] Minimum number of poll calls (assuming slots are available).
        attr_reader :minimum
        # @return [Integer] Maximum number of poll calls that will ever be open at once.
        attr_reader :maximum
        # @return [Integer] Number of polls attempted initially before scaling kicks in.
        attr_reader :initial

        # @param minimum [Integer] Minimum number of poll calls (assuming slots are available).
        # @param maximum [Integer] Maximum number of poll calls that will ever be open at once.
        # @param initial [Integer] Number of polls attempted initially before scaling kicks in.
        def initialize(minimum: 1, maximum: 100, initial: 5)
          super()
          @minimum = minimum
          @maximum = maximum
          @initial = initial
        end

        # @!visibility private
        def _to_bridge_options
          Internal::Bridge::Worker::PollerBehaviorAutoscaling.new(
            minimum: @minimum,
            maximum: @maximum,
            initial: @initial
          )
        end
      end
    end
  end
end
