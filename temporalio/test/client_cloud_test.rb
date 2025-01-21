# frozen_string_literal: true

require 'securerandom'
require 'temporalio/api'
require 'temporalio/client'
require 'test'

class ClientCloudTest < Test
  class SimpleWorkflow < Temporalio::Workflow::Definition
    def execute(name)
      "Hello, #{name}!"
    end
  end

  def test_mtls
    client_private_key = ENV.fetch('TEMPORAL_CLOUD_MTLS_TEST_CLIENT_KEY', '')
    skip('No cloud mTLS key') if client_private_key.empty?

    client = Temporalio::Client.connect(
      ENV.fetch('TEMPORAL_CLOUD_MTLS_TEST_TARGET_HOST'),
      ENV.fetch('TEMPORAL_CLOUD_MTLS_TEST_NAMESPACE'),
      tls: Temporalio::Client::Connection::TLSOptions.new(
        client_cert: ENV.fetch('TEMPORAL_CLOUD_MTLS_TEST_CLIENT_CERT'),
        client_private_key:
      )
    )
    assert_equal 'Hello, Temporal!', execute_workflow(SimpleWorkflow, 'Temporal', client:)
  end

  def test_api_key
    api_key = ENV.fetch('TEMPORAL_CLOUD_API_KEY_TEST_API_KEY', '')
    skip('No cloud API key') if api_key.empty?

    client = Temporalio::Client.connect(
      ENV.fetch('TEMPORAL_CLOUD_API_KEY_TEST_TARGET_HOST'),
      ENV.fetch('TEMPORAL_CLOUD_API_KEY_TEST_NAMESPACE'),
      api_key:,
      tls: true,
      rpc_metadata: { 'temporal-namespace' => ENV.fetch('TEMPORAL_CLOUD_API_KEY_TEST_NAMESPACE') }
    )
    # Run workflow
    id = "wf-#{SecureRandom.uuid}"
    assert_equal 'Hello, Temporal!', execute_workflow(SimpleWorkflow, 'Temporal', id:, client:)
    handle = client.workflow_handle(id)

    # Confirm it can be described
    assert_equal 'SimpleWorkflow', handle.describe.workflow_type

    # Change API and confirm failure
    client.connection.api_key = 'wrong'
    assert_raises(Temporalio::Error::RPCError) { handle.describe.workflow_type }
  end

  def test_cloud_ops
    api_key = ENV.fetch('TEMPORAL_CLOUD_OPS_TEST_API_KEY', '')
    skip('No cloud API key') if api_key.empty?

    # Create connection
    conn = Temporalio::Client::Connection.new(
      target_host: ENV.fetch('TEMPORAL_CLOUD_OPS_TEST_TARGET_HOST'),
      api_key:,
      tls: true,
      rpc_metadata: { 'temporal-cloud-api-version' => ENV.fetch('TEMPORAL_CLOUD_OPS_TEST_API_VERSION') }
    )

    # Simple call
    namespace = ENV.fetch('TEMPORAL_CLOUD_OPS_TEST_NAMESPACE')
    res = conn.cloud_service.get_namespace(
      Temporalio::Api::Cloud::CloudService::V1::GetNamespaceRequest.new(namespace:)
    )
    assert_equal namespace, res.namespace.namespace
  end
end
