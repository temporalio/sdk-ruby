# typed: false
# frozen_string_literal: true

# Generated code.  DO NOT EDIT!

class Temporalio::Client::Connection::OperatorService < ::Temporalio::Client::Connection::Service
  extend T::Sig

  sig { params(connection: Temporalio::Client::Connection).void }
  def initialize(connection); end

  sig { params(request: Temporalio::Api::OperatorService::V1::AddSearchAttributesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::AddSearchAttributesResponse) }
  def add_search_attributes(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::RemoveSearchAttributesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::RemoveSearchAttributesResponse) }
  def remove_search_attributes(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::ListSearchAttributesRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::ListSearchAttributesResponse) }
  def list_search_attributes(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::DeleteNamespaceRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::DeleteNamespaceResponse) }
  def delete_namespace(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::AddOrUpdateRemoteClusterRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::AddOrUpdateRemoteClusterResponse) }
  def add_or_update_remote_cluster(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::RemoveRemoteClusterRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::RemoveRemoteClusterResponse) }
  def remove_remote_cluster(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::ListClustersRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::ListClustersResponse) }
  def list_clusters(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::GetNexusEndpointRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::GetNexusEndpointResponse) }
  def get_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::CreateNexusEndpointRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::CreateNexusEndpointResponse) }
  def create_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::UpdateNexusEndpointRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::UpdateNexusEndpointResponse) }
  def update_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::DeleteNexusEndpointRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::DeleteNexusEndpointResponse) }
  def delete_nexus_endpoint(request, rpc_options: T.unsafe(nil)); end

  sig { params(request: Temporalio::Api::OperatorService::V1::ListNexusEndpointsRequest, rpc_options: T.nilable(Temporalio::Client::RPCOptions)).returns(Temporalio::Api::OperatorService::V1::ListNexusEndpointsResponse) }
  def list_nexus_endpoints(request, rpc_options: T.unsafe(nil)); end
end
