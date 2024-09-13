# frozen_string_literal: true

module Temporalio
  class Activity
    # Definition of an activity. Activities are usually classes/instances that extend {Activity}, but definitions can
    # also be manually created with a proc/block.
    class Definition
      # @return [String, Symbol] Name of the activity.
      attr_reader :name

      # @return [Proc] Proc for the activity.
      attr_reader :proc

      # @return [Symbol] Name of the executor. Default is `:default`.
      attr_reader :executor

      # @return [Boolean] Whether to raise in thread/fiber on cancellation. Default is `true`.
      attr_reader :cancel_raise

      # Obtain a definition representing the given activity, which can be a class, instance, or definition.
      #
      # @param activity [Activity, Class<Activity>, Definition] Activity to get definition for.
      # @return Definition Obtained definition.
      def self.from_activity(activity)
        # Class means create each time, instance means just call, definition
        # does nothing special
        case activity
        when Class
          raise ArgumentError, "Class '#{activity}' does not extend Activity" unless activity < Activity

          details = activity._activity_definition_details
          new(
            name: details[:activity_name],
            executor: details[:activity_executor],
            cancel_raise: details[:activity_cancel_raise],
            # Instantiate and call
            proc: proc { |*args| activity.new.execute(*args) }
          )
        when Activity
          details = activity.class._activity_definition_details
          new(
            name: details[:activity_name],
            executor: details[:activity_executor],
            cancel_raise: details[:activity_cancel_raise],
            # Just call
            proc: proc { |*args| activity.execute(*args) }
          )
        when Activity::Definition
          activity
        else
          raise ArgumentError, "#{activity} is not an activity class, instance, or definition"
        end
      end

      # Manually create activity definition. Most users will use an instance/class of {Activity}.
      #
      # @param name [String, Symbol] Name of the activity.
      # @param proc [Proc, nil] Proc for the activity, or can give block.
      # @param executor [Symbol] Name of the executor.
      # @param cancel_raise [Boolean] Whether to raise in thread/fiber on cancellation.
      # @yield Use this block as the activity. Cannot be present with `proc`.
      def initialize(name:, proc: nil, executor: :default, cancel_raise: true, &block)
        @name = name
        if proc.nil?
          raise ArgumentError, 'Must give proc or block' unless block_given?

          proc = block
        elsif block_given?
          raise ArgumentError, 'Cannot give proc and block'
        end
        @proc = proc
        @executor = executor
        @cancel_raise = cancel_raise
      end
    end
  end
end
