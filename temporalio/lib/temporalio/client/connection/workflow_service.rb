# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/connection/service'
require 'temporalio/internal/bridge/client'

module Temporalio
  class Client
    class Connection
      # Raw gRPC workflow service as defined at
      # https://github.com/temporalio/api/blob/master/temporal/api/workflowservice/v1/service.proto.
      class WorkflowService < Service
        rpc_methods(
          Internal::Bridge::Client::SERVICE_WORKFLOW,
          'temporal.api.workflowservice.v1.WorkflowService'
        )
      end
    end
  end
end
