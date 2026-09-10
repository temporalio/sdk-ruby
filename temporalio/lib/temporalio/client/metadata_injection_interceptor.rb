# frozen_string_literal: true

require 'temporalio/client/metadata_provider'

module Temporalio
  class Client
    # Interceptor that injects metadata from a provider into all requests
    class MetadataInjectionInterceptor
      include Interceptor

      def initialize(metadata_provider)
        @metadata_provider = metadata_provider
      end

      def intercept_client(next_interceptor)
        MetadataInjectingOutbound.new(next_interceptor, @metadata_provider)
      end

      # Outbound that injects metadata
      class MetadataInjectingOutbound
        def initialize(next_outbound, metadata_provider)
          @next_outbound = next_outbound
          @metadata_provider = metadata_provider
        end

        def start_workflow(input)
          inject_metadata(input)
          @next_outbound.start_workflow(input)
        end

        def signal_with_start_workflow(input)
          inject_metadata(input)
          @next_outbound.signal_with_start_workflow(input)
        end

        def start_update_with_start_workflow(input)
          inject_metadata(input)
          @next_outbound.start_update_with_start_workflow(input)
        end

        def list_workflow_page(input)
          inject_metadata(input)
          @next_outbound.list_workflow_page(input)
        end

        def count_workflows(input)
          inject_metadata(input)
          @next_outbound.count_workflows(input)
        end

        def describe_workflow(input)
          inject_metadata(input)
          @next_outbound.describe_workflow(input)
        end

        def fetch_workflow_history_events(input)
          inject_metadata(input)
          @next_outbound.fetch_workflow_history_events(input)
        end

        def query_workflow(input)
          inject_metadata(input)
          @next_outbound.query_workflow(input)
        end

        def signal_workflow(input)
          inject_metadata(input)
          @next_outbound.signal_workflow(input)
        end

        def signal_workflow_with_start(input)
          inject_metadata(input)
          @next_outbound.signal_workflow_with_start(input)
        end

        def request_cancel_workflow(input)
          inject_metadata(input)
          @next_outbound.request_cancel_workflow(input)
        end

        def terminate_workflow(input)
          inject_metadata(input)
          @next_outbound.terminate_workflow(input)
        end

        def update_workflow(input)
          inject_metadata(input)
          @next_outbound.update_workflow(input)
        end

        private

        def inject_metadata(input)
          provider_metadata = @metadata_provider.metadata
          return if provider_metadata.empty?

          if input.respond_to?(:rpc_options=)
            current_rpc_options = input.rpc_options || {}
            current_metadata = current_rpc_options.is_a?(Hash) ? current_rpc_options : {}
            merged_metadata = current_metadata.merge(provider_metadata)
            input.rpc_options = merged_metadata
          end
        end
      end
    end
  end
end
