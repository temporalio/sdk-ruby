module Temporalio
  class Workflow
    def self.workflow_name(new_name)
      @workflow_name = new_name
    end

    # @api private
    def self._name
      @workflow_name || name || ''
    end

    # @api private
    def initialize(context)
      @context = context
    end

    def execute(*_args)
      raise NoMethodError, 'must implement #execute'
    end

    private

    def workflow
      @context
    end
  end
end
