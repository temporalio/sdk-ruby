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
        def execute_activity(defn, &) # rubocop:disable Lint/UnusedMethodArgument
          ::Fiber.schedule(&)
        end

        # @see ActivityExecutor.activity_context
        def activity_context
          ::Fiber[:temporal_activity_context]
        end

        # @see ActivityExecutor.set_activity_context
        def set_activity_context(defn, context)
          ::Fiber[:temporal_activity_context] = context
          # If they have opted in to raising on cancel, wire that up
          return unless defn.cancel_raise

          fiber = ::Fiber.current
          # Cancel callbacks run on the canceler's fiber, which for activity cancellation is the
          # worker's single task-dispatch fiber. Fiber#raise uses resume semantics, so under a
          # scheduler that drives fibers with Fiber#transfer (e.g. async) the target never returns
          # to its resumer and the dispatch fiber is suspended forever, wedging the whole worker.
          # Schedulers expose fiber_interrupt (Ruby 3.3+) to perform the raise themselves, which
          # returns to the caller immediately.
          scheduler = ::Fiber.scheduler
          scheduler = nil unless scheduler.respond_to?(:fiber_interrupt)
          context&.cancellation&.add_cancel_callback do
            error = Error::CanceledError.new('Activity canceled')
            if scheduler
              scheduler.fiber_interrupt(fiber, error)
            else
              fiber.raise(error)
            end
          end
        end
      end
    end
  end
end
