module Temporal
  class Activity
    def self.activity_name(new_name)
      @activity_name = new_name
    end

    def self.shielded!
      @shielded = true
    end

    def self._name
      @activity_name || name || ''
    end

    def self._shielded
      @shielded || false
    end

    def initialize(context)
      @context = context
    end

    def execute(*_args)
      raise NoMethodError, 'must implement #execute'
    end

    private

    def activity
      @context
    end
  end
end
