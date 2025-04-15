# frozen_string_literal: true

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Details needed to instantiate a {WorkflowInstance}.
        class Details
          attr_reader :namespace, :task_queue, :definition, :initial_activation, :logger, :metric_meter,
                      :payload_converter, :failure_converter, :interceptors, :disable_eager_activity_execution,
                      :illegal_calls, :workflow_failure_exception_types, :unsafe_workflow_io_enabled

          def initialize(
            namespace:,
            task_queue:,
            definition:,
            initial_activation:,
            logger:,
            metric_meter:,
            payload_converter:,
            failure_converter:,
            interceptors:,
            disable_eager_activity_execution:,
            illegal_calls:,
            workflow_failure_exception_types:,
            unsafe_workflow_io_enabled:
          )
            @namespace = namespace
            @task_queue = task_queue
            @definition = definition
            @initial_activation = initial_activation
            @logger = logger
            @metric_meter = metric_meter
            @payload_converter = payload_converter
            @failure_converter = failure_converter
            @interceptors = interceptors
            @disable_eager_activity_execution = disable_eager_activity_execution
            @illegal_calls = illegal_calls
            @workflow_failure_exception_types = workflow_failure_exception_types
            @unsafe_workflow_io_enabled = unsafe_workflow_io_enabled
          end
        end
      end
    end
  end
end
