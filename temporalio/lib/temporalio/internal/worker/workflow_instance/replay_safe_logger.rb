# frozen_string_literal: true

require 'temporalio/scoped_logger'
require 'temporalio/workflow'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Wrapper for a scoped logger that does not log on replay.
        class ReplaySafeLogger < ScopedLogger
          def initialize(logger:, instance:)
            @instance = instance
            @replay_safety_disabled = false
            super(logger)
          end

          def replay_safety_disabled(&)
            @replay_safety_disabled = true
            yield
          ensure
            @replay_safety_disabled = false
          end

          def add(...)
            if !@replay_safety_disabled && Temporalio::Workflow.in_workflow? &&
               Temporalio::Workflow::Unsafe.replaying_history_events?
              return true
            end

            # Disable scheduler since logs technically have local mutexes in them that cannot be done durably or they
            # will block workflows
            @instance.context.durable_scheduler_disabled do
              super
            end
          end
        end
      end
    end
  end
end
