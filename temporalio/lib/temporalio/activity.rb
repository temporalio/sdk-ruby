# frozen_string_literal: true

require 'temporalio/activity/complete_async_error'
require 'temporalio/activity/context'
require 'temporalio/activity/definition'
require 'temporalio/activity/info'

module Temporalio
  # Base class for all activities.
  #
  # Activities can be given to a worker as instances of this class, which will call execute on the same instance for
  # each execution, or given to the worker as the class itself which instantiates the activity for each execution.
  #
  # All activities must implement {execute}. Inside execute, {Activity::Context.current} can be used to access the
  # current context to get information, issue heartbeats, etc.
  #
  # By default, the activity is named as its unqualified class name. This can be customized with {activity_name}.
  #
  # By default, the activity uses the `:default` executor which is usually the thread-pool based executor. This can be
  # customized with {activity_executor}.
  #
  # By default, upon cancellation {::Thread.raise} or {::Fiber.raise} is called with a {Error::CanceledError}. This can
  # be disabled by passing `false` to {activity_cancel_raise}.
  #
  # See documentation for more detail on activities.
  class Activity
    # Override the activity name which is defaulted to the unqualified class name.
    #
    # @param name [String, Symbol] Name to use.
    def self.activity_name(name)
      raise ArgumentError, 'Activity name must be a symbol or string' if !name.is_a?(Symbol) && !name.is_a?(String)

      @activity_name = name.to_s
    end

    # Override the activity executor which is defaulted to `:default`.
    #
    # @param executor_name [Symbol] Executor to use.
    def self.activity_executor(executor_name)
      raise ArgumentError, 'Executor name must be a symbol' unless executor_name.is_a?(Symbol)

      @activity_executor = executor_name
    end

    # Override whether the activity uses Thread/Fiber raise for cancellation which is defaulted to true.
    #
    # @param cancel_raise [Boolean] Whether to raise.
    def self.activity_cancel_raise(cancel_raise)
      raise ArgumentError, 'Must be a boolean' unless cancel_raise.is_a?(TrueClass) || cancel_raise.is_a?(FalseClass)

      @activity_cancel_raise = cancel_raise
    end

    # @!visibility private
    def self._activity_definition_details
      {
        activity_name: @activity_name || name.to_s.split('::').last,
        activity_executor: @activity_executor || :default,
        activity_cancel_raise: @activity_cancel_raise.nil? ? true : @activity_cancel_raise
      }
    end

    # Implementation of the activity. The arguments should be positional and this should return the value on success or
    # raise an error on failure.
    def execute(*args)
      raise NotImplementedError, 'Activity did not implement "execute"'
    end
  end
end
