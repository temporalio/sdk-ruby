# frozen_string_literal: true

require 'temporalio/cancellation'
require 'temporalio/workflow'
require 'temporalio/workflow/external_workflow_handle'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Implementation of the external workflow handle.
        class ExternalWorkflowHandle < Workflow::ExternalWorkflowHandle
          attr_reader :id, :run_id

          def initialize(id:, run_id:, instance:) # rubocop:disable Lint/MissingSuper
            @id = id
            @run_id = run_id
            @instance = instance
          end

          def signal(signal, *args, cancellation: Workflow.cancellation)
            @instance.context._signal_external_workflow(id:, run_id:, signal:, args:, cancellation:)
          end

          def cancel
            @instance.context._cancel_external_workflow(id:, run_id:)
          end
        end
      end
    end
  end
end
