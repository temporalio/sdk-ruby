# frozen_string_literal: true

module Temporalio
  module Activity
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
    # By default, upon cancellation {::Thread.raise} or {::Fiber.raise} is called with a {Error::CanceledError}. This
    # can be disabled by passing `false` to {activity_cancel_raise}.
    #
    # See documentation for more detail on activities.
    class Definition
      class << self
        protected

        # Override the activity name which is defaulted to the unqualified class name.
        #
        # @param name [String, Symbol] Name to use.
        def activity_name(name)
          if !name.is_a?(Symbol) && !name.is_a?(String)
            raise ArgumentError,
                  'Activity name must be a symbol or string'
          end

          @activity_name = name.to_s
        end

        # Override the activity executor which is defaulted to `:default`.
        #
        # @param executor_name [Symbol] Executor to use.
        def activity_executor(executor_name)
          raise ArgumentError, 'Executor name must be a symbol' unless executor_name.is_a?(Symbol)

          @activity_executor = executor_name
        end

        # Override whether the activity uses Thread/Fiber raise for cancellation which is defaulted to true.
        #
        # @param cancel_raise [Boolean] Whether to raise.
        def activity_cancel_raise(cancel_raise)
          unless cancel_raise.is_a?(TrueClass) || cancel_raise.is_a?(FalseClass)
            raise ArgumentError,
                  'Must be a boolean'
          end

          @activity_cancel_raise = cancel_raise
        end
      end

      # @!visibility private
      def self._activity_definition_details
        {
          activity_name: @activity_name || name.to_s.split('::').last,
          activity_executor: @activity_executor || :default,
          activity_cancel_raise: @activity_cancel_raise.nil? ? true : @activity_cancel_raise
        }
      end

      # Implementation of the activity. The arguments should be positional and this should return the value on success
      # or raise an error on failure.
      def execute(*args)
        raise NotImplementedError, 'Activity did not implement "execute"'
      end

      # Definition info of an activity. Activities are usually classes/instances that extend {Definition}, but
      # definitions can also be manually created with a block via {initialize} here.
      class Info
        # @return [String, Symbol] Name of the activity.
        attr_reader :name

        # @return [Proc] Proc for the activity.
        attr_reader :proc

        # @return [Symbol] Name of the executor. Default is `:default`.
        attr_reader :executor

        # @return [Boolean] Whether to raise in thread/fiber on cancellation. Default is `true`.
        attr_reader :cancel_raise

        # Obtain definition info representing the given activity, which can be a class, instance, or definition info.
        #
        # @param activity [Definition, Class<Definition>, Info] Activity to get info for.
        # @return Info Obtained definition info.
        def self.from_activity(activity)
          # Class means create each time, instance means just call, definition
          # does nothing special
          case activity
          when Class
            unless activity < Definition
              raise ArgumentError,
                    "Class '#{activity}' does not extend Temporalio::Activity::Definition"
            end

            details = activity._activity_definition_details
            new(
              name: details[:activity_name],
              executor: details[:activity_executor],
              cancel_raise: details[:activity_cancel_raise]
            ) { |*args| activity.new.execute(*args) } # Instantiate and call
          when Definition
            details = activity.class._activity_definition_details
            new(
              name: details[:activity_name],
              executor: details[:activity_executor],
              cancel_raise: details[:activity_cancel_raise]
            ) { |*args| activity.execute(*args) } # Just and call
          when Info
            activity
          else
            raise ArgumentError, "#{activity} is not an activity class, instance, or definition info"
          end
        end

        # Manually create activity definition info. Most users will use an instance/class of {Definition}.
        #
        # @param name [String, Symbol] Name of the activity.
        # @param executor [Symbol] Name of the executor.
        # @param cancel_raise [Boolean] Whether to raise in thread/fiber on cancellation.
        # @yield Use this block as the activity.
        def initialize(name:, executor: :default, cancel_raise: true, &block)
          @name = name
          raise ArgumentError, 'Must give block' unless block_given?

          @proc = block
          @executor = executor
          @cancel_raise = cancel_raise
        end
      end
    end
  end
end
