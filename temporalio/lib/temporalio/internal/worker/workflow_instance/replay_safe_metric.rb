# frozen_string_literal: true

require 'temporalio/scoped_logger'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Wrapper for a metric that does not log on replay.
        class ReplaySafeMetric < SimpleDelegator
          def record(value, additional_attributes: nil)
            return if Temporalio::Workflow.in_workflow? &&
                      Temporalio::Workflow::Unsafe.replaying_history_events?

            super
          end

          def with_additional_attributes(additional_attributes)
            ReplaySafeMetric.new(super)
          end

          class Meter < SimpleDelegator
            def create_metric(
              metric_type,
              name,
              description: nil,
              unit: nil,
              value_type: :integer
            )
              ReplaySafeMetric.new(super)
            end

            def with_additional_attributes(additional_attributes)
              Meter.new(super)
            end
          end
        end
      end
    end
  end
end
