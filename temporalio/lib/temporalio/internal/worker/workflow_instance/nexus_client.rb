# frozen_string_literal: true

require 'temporalio/workflow'
require 'temporalio/workflow/nexus_client'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Implementation of the Nexus client.
        class NexusClient < Workflow::NexusClient
          attr_reader :endpoint, :service

          def initialize(endpoint:, service:, outbound:) # rubocop:disable Lint/MissingSuper
            @endpoint = endpoint.to_s
            @service = service.to_s
            @outbound = outbound
          end

          def start_operation(operation, arg, schedule_to_close_timeout: nil, cancellation_type: nil, summary: nil,
                              cancellation: Workflow.cancellation, arg_hint: nil, result_hint: nil)
            @outbound.start_nexus_operation(
              Temporalio::Worker::Interceptor::Workflow::StartNexusOperationInput.new(
                endpoint: @endpoint,
                service: @service,
                operation: operation.to_s,
                arg:,
                schedule_to_close_timeout:,
                cancellation_type:,
                summary:,
                cancellation:,
                arg_hint:,
                result_hint:,
                headers: {}
              )
            )
          end
        end
      end
    end
  end
end
