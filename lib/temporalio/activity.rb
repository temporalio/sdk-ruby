module Temporalio
  # This is an abstract superclass for implementing activities.
  #
  # Temporal SDK users are expected to subclass it and implement the {#execute} method by adding
  # their desired business logic.
  #
  # @abstract
  #
  # @example "Hello World" Activity
  #   class HelloWorld < Temporalio::Activity
  #     def execute(name)
  #       "Hello, #{name}!"
  #     end
  #   end
  class Activity
    # Specify a custom name to be used for this activity.
    #
    # By default a full class (with any namespace modules/classes) name will be used.
    #
    # @param new_name [String] Name to be used for this activity
    #
    # @example
    #   class Test < Temporalio::Activity
    #     activity_name 'custom-activity-name'
    #
    #     def execute
    #       ...
    #     end
    #   end
    def self.activity_name(new_name)
      @activity_name = new_name
    end

    # Mark the activity as shielded from cancellations.
    #
    # Activity cancellations are implemented using the `Thread#raise`, which can unsafely terminate
    # your implementation. To disable this behaviour make sure to mark critical activities as
    # `shielded!`. For shielding a part of your activity consider using
    # {Temporalio::Activity::Context#shield}.
    #
    # @example
    #   class Test < Temporalio::Activity
    #     shielded!
    #
    #     def execute
    #       ...
    #     end
    #   end
    def self.shielded!
      @shielded = true
    end

    # @api private
    def self._name
      @activity_name || name || ''
    end

    # @api private
    def self._shielded
      @shielded || false
    end

    # @api private
    def initialize(context)
      @context = context
    end

    # This is the main body of your activity's implementation.
    #
    # When implementing this method, you can use as many positional arguments as needed, which will
    # get converted based on the activity invocation in your workflow.
    #
    # Inside of this method you have access to activity's context using the `activity` method. Check
    # out {Temporalio::Activity::Context} for more information on how to use it.
    def execute(*_args)
      raise NoMethodError, 'must implement #execute'
    end

    private

    def activity
      @context
    end
  end
end
