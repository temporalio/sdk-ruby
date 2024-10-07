# frozen_string_literal: true

require 'temporalio/worker/activity_executor/fiber'
require 'temporalio/worker/activity_executor/thread_pool'

module Temporalio
  class Worker
    # Base class to be extended by activity executor implementations. Most users will not use this, but rather keep with
    # the two defaults of thread pool and fiber executors.
    class ActivityExecutor
      # @return [Hash<Symbol, ActivityExecutor>] Default set of executors (immutable).
      def self.defaults
        @defaults ||= {
          default: ThreadPool.default,
          thread_pool: ThreadPool.default,
          fiber: Fiber.default
        }.freeze
      end

      # Initialize an activity. This is called on worker initialize for every activity that will use this executor. This
      # allows executor implementations to do eager validation based on the definition. This does not have to be
      # implemented and the default is a no-op.
      #
      # @param defn [Activity::Definition] Activity definition.
      def initialize_activity(defn)
        # Default no-op
      end

      # Execute the given block in the executor. The block is built to never raise and need no arguments. Implementers
      # must implement this.
      #
      # @param defn [Activity::Definition] Activity definition.
      # @yield Block to execute.
      def execute_activity(defn, &)
        raise NotImplementedError
      end

      # @return [Activity::Context, nil] Get the current activity context. This is called by users from inside the
      #   activity. Implementers must implement this.
      def activity_context
        raise NotImplementedError
      end

      # Set the current activity context (or unset if nil). This is called by the system from within the block given to
      # {execute_activity} with a context before user code is executed and with nil after user code is complete.
      # Implementers must implement this.
      #
      # @param context [Activity::Context, nil] The value to set.
      def activity_context=(context)
        raise NotImplementedError
      end
    end
  end
end
