# frozen_string_literal: true

require 'stringio'
require 'tempfile'
require 'test'

require_relative '../../.github/scripts/cloud_namespace'

class CloudNamespaceScriptTest < Test
  class FakeCloudService
    attr_accessor :create_error, :create_response, :delete_response, :namespace_error, :namespace_response,
                  :namespaces_response, :operation_error
    attr_reader :create_request, :delete_request, :operation_requests, :rpc_options

    def initialize(operation_responses: [])
      @operation_responses = operation_responses
      @operation_requests = []
    end

    def create_namespace(request, rpc_options:)
      @create_request = request
      @rpc_options = rpc_options
      raise create_error if create_error

      create_response
    end

    def delete_namespace(request, rpc_options:)
      @delete_request = request
      @rpc_options = rpc_options
      delete_response
    end

    def get_namespace(_request, rpc_options:)
      @rpc_options = rpc_options
      raise namespace_error if namespace_error

      namespace_response
    end

    def get_namespaces(_request, rpc_options:)
      @rpc_options = rpc_options
      namespaces_response
    end

    def get_async_operation(request, rpc_options:)
      @operation_requests << request
      @rpc_options = rpc_options
      raise operation_error if operation_error

      operation = @operation_responses.shift || raise('No operation response configured')
      Temporalio::Api::Cloud::CloudService::V1::GetAsyncOperationResponse.new(async_operation: operation)
    end
  end

  def test_create_namespace
    service = FakeCloudService.new(operation_responses: [operation(:STATE_FULFILLED)])
    service.create_response = Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceResponse.new(
      namespace: 'sdk-ruby-ci-123-2.account-id',
      async_operation: operation(:STATE_PENDING)
    )
    service.namespace_response = namespace_response(
      namespace: 'sdk-ruby-ci-123-2.account-id',
      address: 'sdk-ruby-ci-123-2.account-id.tmprl.cloud:7233'
    )

    with_ca_env do |env|
      output = StringIO.new
      CloudNamespace.create(service:, env:, output:, monotonic: -> { 0 }, sleeper: ->(_duration) {})

      request = service.create_request
      assert_equal 'sdk-ruby-ci-123-2', request.spec.name
      assert_equal ['aws-ca-central-1'], request.spec.regions
      assert_equal 1, request.spec.retention_days
      assert request.spec.mtls_auth.enabled
      assert_equal 'test-ca', request.spec.mtls_auth.accepted_client_ca
      refute_empty request.async_operation_id
      assert_equal 30, service.rpc_options.timeout
      assert service.rpc_options.override_retry
      assert_equal <<~OUTPUT, output.string
        namespace_name=sdk-ruby-ci-123-2
        namespace=sdk-ruby-ci-123-2.account-id
        address=sdk-ruby-ci-123-2.account-id.tmprl.cloud:7233
      OUTPUT
    end
  end

  def test_create_records_namespace_before_create_failure
    service = FakeCloudService.new
    service.create_error = RuntimeError.new('create response lost')

    with_ca_env do |env|
      output = StringIO.new
      error = assert_raises(RuntimeError) do
        CloudNamespace.create(service:, env:, output:, monotonic: -> { 0 }, sleeper: ->(_duration) {})
      end
      assert_equal "namespace_name=sdk-ruby-ci-123-2\n", output.string
      assert_includes error.message, 'create response lost'
    end
  end

  def test_wait_for_operation_honors_check_duration_and_timeout
    service = FakeCloudService.new(
      operation_responses: [operation(:STATE_PENDING, check_seconds: 2.5), operation(:STATE_FULFILLED)]
    )
    delays = []
    CloudNamespace.wait_for_operation(
      service,
      operation(:STATE_PENDING),
      monotonic: -> { 0 },
      sleeper: ->(duration) { delays << duration }
    )
    assert_equal [2.5], delays

    times = [0, CloudNamespace::OPERATION_TIMEOUT_SECONDS + 1]
    service = FakeCloudService.new(operation_responses: [operation(:STATE_PENDING)])
    assert_raises(Timeout::Error) do
      CloudNamespace.wait_for_operation(
        service,
        operation(:STATE_PENDING),
        monotonic: -> { times.shift || times.last },
        sleeper: ->(_duration) {}
      )
    end
  end

  def test_delete_namespace_uses_resource_version
    service = FakeCloudService.new(operation_responses: [operation(:STATE_FULFILLED)])
    service.namespace_response = namespace_response(namespace: 'sdk-ruby-ci-123-2', resource_version: 'version-1')
    service.delete_response = Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceResponse.new(
      async_operation: operation(:STATE_PENDING)
    )

    CloudNamespace.delete(
      service:,
      namespace: 'sdk-ruby-ci-123-2',
      monotonic: -> { 0 },
      sleeper: ->(_duration) {}
    )

    assert_equal 'sdk-ruby-ci-123-2', service.delete_request.namespace
    assert_equal 'version-1', service.delete_request.resource_version
    refute_empty service.delete_request.async_operation_id
    assert_equal 30, service.rpc_options.timeout
    assert service.rpc_options.override_retry
  end

  def test_delete_resolves_namespace_name_after_ambiguous_create
    service = FakeCloudService.new(operation_responses: [operation(:STATE_FULFILLED)])
    service.namespaces_response = Temporalio::Api::Cloud::CloudService::V1::GetNamespacesResponse.new(
      namespaces: [
        Temporalio::Api::Cloud::Namespace::V1::Namespace.new(
          namespace: 'sdk-ruby-ci-123-2.account-id',
          spec: Temporalio::Api::Cloud::Namespace::V1::NamespaceSpec.new(name: 'sdk-ruby-ci-123-2')
        )
      ]
    )
    service.namespace_response = namespace_response(
      namespace: 'sdk-ruby-ci-123-2.account-id',
      resource_version: 'version-1'
    )
    service.delete_response = Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceResponse.new(
      async_operation: operation(:STATE_PENDING)
    )

    CloudNamespace.delete(
      service:,
      namespace_name: 'sdk-ruby-ci-123-2',
      monotonic: -> { 0 },
      sleeper: ->(_duration) {}
    )

    assert_equal 'sdk-ruby-ci-123-2.account-id', service.delete_request.namespace
  end

  def test_delete_only_ignores_not_found_while_locating_namespace
    service = FakeCloudService.new
    service.namespace_error = rpc_not_found
    CloudNamespace.delete(service:, namespace: 'missing.account-id')
    assert_nil service.delete_request

    service = FakeCloudService.new
    service.namespace_response = namespace_response(namespace: 'existing.account-id', resource_version: 'version-1')
    service.delete_response = Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceResponse.new(
      async_operation: operation(:STATE_PENDING)
    )
    service.operation_error = rpc_not_found
    assert_raises(Temporalio::Error::RPCError) do
      CloudNamespace.delete(service:, namespace: 'existing.account-id')
    end
  end

  private

  def operation(state, failure_reason: '', check_seconds: nil)
    duration = if check_seconds
                 seconds = check_seconds.floor
                 Google::Protobuf::Duration.new(
                   seconds:,
                   nanos: ((check_seconds - seconds) * 1_000_000_000).to_i
                 )
               end
    Temporalio::Api::Cloud::Operation::V1::AsyncOperation.new(
      id: 'operation-id',
      state:,
      failure_reason:,
      check_duration: duration
    )
  end

  def namespace_response(namespace:, resource_version: '', address: '')
    Temporalio::Api::Cloud::CloudService::V1::GetNamespaceResponse.new(
      namespace: Temporalio::Api::Cloud::Namespace::V1::Namespace.new(
        namespace:,
        resource_version:,
        endpoints: Temporalio::Api::Cloud::Namespace::V1::Endpoints.new(mtls_grpc_address: address)
      )
    )
  end

  def rpc_not_found
    Temporalio::Error::RPCError.new(
      'not found',
      code: Temporalio::Error::RPCError::Code::NOT_FOUND,
      raw_grpc_status: nil
    )
  end

  def with_ca_env
    Tempfile.create do |file|
      file.write('test-ca')
      file.flush
      yield(
        'GITHUB_RUN_ID' => '123',
        'GITHUB_RUN_ATTEMPT' => '2',
        'TEMPORAL_CLOUD_CLIENT_CA_PATH' => file.path
      )
    end
  end
end
