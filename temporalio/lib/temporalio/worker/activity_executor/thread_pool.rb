# frozen_string_literal: true

require 'temporalio/worker/thread_pool'

module Temporalio
  class Worker
    class ActivityExecutor
      # Activity executor for scheduling activities in their own thread using {Worker::ThreadPool}.
      class ThreadPool < ActivityExecutor
        # @return [ThreadPool] Default/shared thread pool executor using default thread pool.
        def self.default
          @default ||= new
        end

        # Create a new thread pool executor.
        #
        # @param thread_pool [Worker::ThreadPool] Thread pool to use.
        def initialize(thread_pool = Worker::ThreadPool.default) # rubocop:disable Lint/MissingSuper
          @thread_pool = thread_pool
        end

        # @see ActivityExecutor.execute_activity
        def execute_activity(_defn, &)
          @thread_pool.execute(&)
        end

        # @see ActivityExecutor.activity_context
        def activity_context
          Thread.current[:temporal_activity_context]
        end

        # @see ActivityExecutor.set_activity_context
        def set_activity_context(defn, context)
          Thread.current[:temporal_activity_context] = context
          # If they have opted in to raising on cancel, wire that up
          return unless defn.cancel_raise

          thread = Thread.current
          context&.cancellation&.add_cancel_callback do
            thread.raise(Error::CanceledError.new('Activity canceled')) if thread[:temporal_activity_context] == context
          end
        end
      end
    end
  end
end
