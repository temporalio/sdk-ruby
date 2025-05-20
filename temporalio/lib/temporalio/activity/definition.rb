# frozen_string_literal: true

require 'temporalio/internal/proto_utils'

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
            raise ArgumentError, 'Must be a boolean'
          end

          @activity_cancel_raise = cancel_raise
        end

        # Set an activity as dynamic. Dynamic activities do not have names and handle any activity that is not otherwise
        # registered. A worker can only have one dynamic activity. It is often useful to use {activity_raw_args} with
        # this.
        #
        # @param value [Boolean] Whether the activity is dynamic.
        def activity_dynamic(value = true) # rubocop:disable Style/OptionalBooleanParameter
          raise ArgumentError, 'Must be a boolean' unless value.is_a?(TrueClass) || value.is_a?(FalseClass)

          @activity_dynamic = value
        end

        # Have activity arguments delivered to `execute` as {Converters::RawValue}s. These are wrappers for the raw
        # payloads that have not been converted to types (but they have been decoded by the codec if present). They can
        # be converted with {Context#payload_converter}.
        #
        # @param value [Boolean] Whether the activity accepts raw arguments.
        def activity_raw_args(value = true) # rubocop:disable Style/OptionalBooleanParameter
          raise ArgumentError, 'Must be a boolean' unless value.is_a?(TrueClass) || value.is_a?(FalseClass)

          @activity_raw_args = value
        end
      end

      # @!visibility private
      def self._activity_definition_details
        activity_name = @activity_name
        raise 'Cannot have activity name specified for dynamic activity' if activity_name && @activity_dynamic

        # Disallow kwargs in execute parameters
        if instance_method(:execute).parameters.any? { |t, _| t == :key || t == :keyreq }
          raise 'Activity execute cannot have keyword arguments'
        end

        # Default to unqualified class name if not dynamic
        activity_name ||= name.to_s.split('::').last unless @activity_dynamic
        {
          activity_name:,
          activity_executor: @activity_executor || :default,
          activity_cancel_raise: @activity_cancel_raise.nil? || @activity_cancel_raise,
          activity_raw_args: @activity_raw_args.nil? ? false : @activity_raw_args
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
        # @return [String, Symbol, nil] Name of the activity, or nil if the activity is dynamic.
        attr_reader :name

        # @return [Object, Proc, nil] The pre-created instance or the proc to create/return it.
        attr_reader :instance

        # @return [Proc] Proc for the activity. Should use {Context#instance} to access the instance.
        attr_reader :proc

        # @return [Symbol] Name of the executor. Default is `:default`.
        attr_reader :executor

        # @return [Boolean] Whether to raise in thread/fiber on cancellation. Default is `true`.
        attr_reader :cancel_raise

        # @return [Boolean] Whether to use {Converters::RawValue}s as arguments.
        attr_reader :raw_args

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
              instance: proc { activity.new },
              executor: details[:activity_executor],
              cancel_raise: details[:activity_cancel_raise],
              raw_args: details[:activity_raw_args]
            ) { |*args| Context.current.instance&.execute(*args) }
          when Definition
            details = activity.class._activity_definition_details
            new(
              name: details[:activity_name],
              instance: activity,
              executor: details[:activity_executor],
              cancel_raise: details[:activity_cancel_raise],
              raw_args: details[:activity_raw_args]
            ) { |*args| Context.current.instance&.execute(*args) }
          when Info
            activity
          else
            raise ArgumentError, "#{activity} is not an activity class, instance, or definition info"
          end
        end

        # Manually create activity definition info. Most users will use an instance/class of {Definition}.
        #
        # @param name [String, Symbol, nil] Name of the activity or nil for dynamic activity.
        # @param instance [Object, Proc, nil] The pre-created instance or the proc to create/return it.
        # @param executor [Symbol] Name of the executor.
        # @param cancel_raise [Boolean] Whether to raise in thread/fiber on cancellation.
        # @param raw_args [Boolean] Whether to use {Converters::RawValue}s as arguments.
        # @yield Use this block as the activity.
        def initialize(
          name:,
          instance: nil,
          executor: :default,
          cancel_raise: true,
          raw_args: false,
          &block
        )
          @name = name
          @instance = instance
          raise ArgumentError, 'Must give block' unless block_given?

          @proc = block
          @executor = executor
          @cancel_raise = cancel_raise
          @raw_args = raw_args
          Internal::ProtoUtils.assert_non_reserved_name(name)
        end
      end
    end
  end
end
