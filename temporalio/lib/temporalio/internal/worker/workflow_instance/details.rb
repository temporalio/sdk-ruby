# frozen_string_literal: true

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Details needed to instantiate a {WorkflowInstance}.
        class Details
          attr_reader :namespace, :task_queue, :definition, :initial_activation, :logger, :payload_converter,
                      :failure_converter, :interceptors, :disable_eager_activity_execution, :illegal_calls,
                      :workflow_failure_exception_types

          def initialize(
            namespace:,
            task_queue:,
            definition:,
            initial_activation:,
            logger:,
            payload_converter:,
            failure_converter:,
            interceptors:,
            disable_eager_activity_execution:,
            illegal_calls:,
            workflow_failure_exception_types:
          )
            @namespace = namespace
            @task_queue = task_queue
            @definition = definition
            @initial_activation = initial_activation
            @logger = logger
            @payload_converter = payload_converter
            @failure_converter = failure_converter
            @interceptors = interceptors
            @disable_eager_activity_execution = disable_eager_activity_execution
            @illegal_calls = illegal_calls
            @workflow_failure_exception_types = workflow_failure_exception_types
          end
        end
      end
    end
  end
end
