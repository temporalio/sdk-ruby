# frozen_string_literal: true

# Generated code.  DO NOT EDIT!

require 'temporalio/api'
require 'temporalio/client/connection/service'
require 'temporalio/internal/bridge/client'

module Temporalio
  class Client
    class Connection
      # OperatorService API.
      class OperatorService < Service
        # @!visibility private
        def initialize(connection)
          super(connection, Internal::Bridge::Client::SERVICE_OPERATOR)
        end

        # Calls OperatorService.AddSearchAttributes API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::AddSearchAttributesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::AddSearchAttributesResponse] API response.
        def add_search_attributes(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'add_search_attributes',
            request_class: Temporalio::Api::OperatorService::V1::AddSearchAttributesRequest,
            response_class: Temporalio::Api::OperatorService::V1::AddSearchAttributesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.RemoveSearchAttributes API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::RemoveSearchAttributesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::RemoveSearchAttributesResponse] API response.
        def remove_search_attributes(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'remove_search_attributes',
            request_class: Temporalio::Api::OperatorService::V1::RemoveSearchAttributesRequest,
            response_class: Temporalio::Api::OperatorService::V1::RemoveSearchAttributesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.ListSearchAttributes API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::ListSearchAttributesRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::ListSearchAttributesResponse] API response.
        def list_search_attributes(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_search_attributes',
            request_class: Temporalio::Api::OperatorService::V1::ListSearchAttributesRequest,
            response_class: Temporalio::Api::OperatorService::V1::ListSearchAttributesResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.DeleteNamespace API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::DeleteNamespaceRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::DeleteNamespaceResponse] API response.
        def delete_namespace(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_namespace',
            request_class: Temporalio::Api::OperatorService::V1::DeleteNamespaceRequest,
            response_class: Temporalio::Api::OperatorService::V1::DeleteNamespaceResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.AddOrUpdateRemoteCluster API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::AddOrUpdateRemoteClusterRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::AddOrUpdateRemoteClusterResponse] API response.
        def add_or_update_remote_cluster(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'add_or_update_remote_cluster',
            request_class: Temporalio::Api::OperatorService::V1::AddOrUpdateRemoteClusterRequest,
            response_class: Temporalio::Api::OperatorService::V1::AddOrUpdateRemoteClusterResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.RemoveRemoteCluster API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::RemoveRemoteClusterRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::RemoveRemoteClusterResponse] API response.
        def remove_remote_cluster(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'remove_remote_cluster',
            request_class: Temporalio::Api::OperatorService::V1::RemoveRemoteClusterRequest,
            response_class: Temporalio::Api::OperatorService::V1::RemoveRemoteClusterResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.ListClusters API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::ListClustersRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::ListClustersResponse] API response.
        def list_clusters(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_clusters',
            request_class: Temporalio::Api::OperatorService::V1::ListClustersRequest,
            response_class: Temporalio::Api::OperatorService::V1::ListClustersResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.GetNexusEndpoint API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::GetNexusEndpointRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::GetNexusEndpointResponse] API response.
        def get_nexus_endpoint(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'get_nexus_endpoint',
            request_class: Temporalio::Api::OperatorService::V1::GetNexusEndpointRequest,
            response_class: Temporalio::Api::OperatorService::V1::GetNexusEndpointResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.CreateNexusEndpoint API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::CreateNexusEndpointRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::CreateNexusEndpointResponse] API response.
        def create_nexus_endpoint(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'create_nexus_endpoint',
            request_class: Temporalio::Api::OperatorService::V1::CreateNexusEndpointRequest,
            response_class: Temporalio::Api::OperatorService::V1::CreateNexusEndpointResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.UpdateNexusEndpoint API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::UpdateNexusEndpointRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::UpdateNexusEndpointResponse] API response.
        def update_nexus_endpoint(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'update_nexus_endpoint',
            request_class: Temporalio::Api::OperatorService::V1::UpdateNexusEndpointRequest,
            response_class: Temporalio::Api::OperatorService::V1::UpdateNexusEndpointResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.DeleteNexusEndpoint API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::DeleteNexusEndpointRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::DeleteNexusEndpointResponse] API response.
        def delete_nexus_endpoint(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'delete_nexus_endpoint',
            request_class: Temporalio::Api::OperatorService::V1::DeleteNexusEndpointRequest,
            response_class: Temporalio::Api::OperatorService::V1::DeleteNexusEndpointResponse,
            request:,
            rpc_options:
          )
        end

        # Calls OperatorService.ListNexusEndpoints API call.
        #
        # @param request [Temporalio::Api::OperatorService::V1::ListNexusEndpointsRequest] API request.
        # @param rpc_options [RPCOptions, nil] Advanced RPC options.
        # @return [Temporalio::Api::OperatorService::V1::ListNexusEndpointsResponse] API response.
        def list_nexus_endpoints(request, rpc_options: nil)
          invoke_rpc(
            rpc: 'list_nexus_endpoints',
            request_class: Temporalio::Api::OperatorService::V1::ListNexusEndpointsRequest,
            response_class: Temporalio::Api::OperatorService::V1::ListNexusEndpointsResponse,
            request:,
            rpc_options:
          )
        end
      end
    end
  end
end
