# frozen_string_literal: true

module Temporalio
  module Internal
    module Client
      class Implementation
        class ListWorkflowPage
          include Enumerable

          def initialize(client, input:)
            @client = client
            @input = input
          end

          def each(...)
            executions.each(...)
          end

          def next_page_token
            response.next_page_token
          end

          def next_page
            return nil if next_page_token.empty?

            @next_page ||= self.class.new(client, input: input.with(next_page_token: next_page_token))
          end

          private

          attr_reader :client, :input

          def executions
            @executions ||= response.executions.map do |raw_info|
              Temporalio::Client::WorkflowExecution.new(raw_info, client.data_converter)
            end
          end

          def response
            @response ||= client.workflow_service.list_workflow_executions(
              request,
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
          end

          def request
            @request ||= Api::WorkflowService::V1::ListWorkflowExecutionsRequest.new(
              namespace: client.namespace,
              query: input.query || '',
              next_page_token: input.next_page_token,
              page_size: input.page_size
            )
          end
        end
      end
    end
  end
end
