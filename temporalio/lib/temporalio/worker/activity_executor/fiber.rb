# frozen_string_literal: true

require 'temporalio/error'
require 'temporalio/worker/activity_executor'

module Temporalio
  class Worker
    class ActivityExecutor
      # Activity executor for scheduling activites as fibers.
      class Fiber
        # @return [Fiber] Default/shared Fiber executor instance.
        def self.default
          @default ||= new
        end

        # @see ActivityExecutor.initialize_activity
        def initialize_activity(defn)
          # If there is not a current scheduler, we're going to preemptively
          # fail the registration
          return unless ::Fiber.current_scheduler.nil?

          raise ArgumentError, "Activity '#{defn.name}' wants a fiber executor but no current fiber scheduler"
        end

        # @see ActivityExecutor.initialize_activity
        def execute_activity(_defn, &)
          ::Fiber.schedule(&)
        end

        # @see ActivityExecutor.activity_context
        def activity_context
          ::Fiber[:temporal_activity_context]
        end

        # @see ActivityExecutor.activity_context=
        def activity_context=(context)
          ::Fiber[:temporal_activity_context] = context
          # If they have opted in to raising on cancel, wire that up
          return unless context&.definition&.cancel_raise

          fiber = ::Fiber.current
          context.cancellation.add_cancel_callback do
            fiber.raise(Error::CanceledError.new('Activity canceled'))
          end
        end
      end
    end
  end
end
