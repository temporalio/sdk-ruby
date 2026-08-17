# frozen_string_literal: true

require 'securerandom'
require 'temporalio/api'
require 'temporalio/client'
require 'timeout'

# Keeps Cloud CI isolated by provisioning and deleting a namespace for each run.
module CloudNamespace
  CLOUD_API_TARGET = 'saas-api.tmprl.cloud:443'
  CLOUD_REGION = 'aws-ca-central-1'
  OPERATION_TIMEOUT_SECONDS = 10 * 60
  RPC_TIMEOUT_SECONDS = 30
  FAILED_OPERATION_STATES = %i[STATE_FAILED STATE_CANCELLED STATE_REJECTED].freeze

  class << self
    # Keep command dispatch separate so lifecycle behavior can be unit-tested without a subprocess.
    def run(args, env: ENV)
      service = cloud_service(env)
      case args
      in ['create']
        File.open(env.fetch('GITHUB_OUTPUT'), 'a') do |output|
          create(service:, env:, output:)
        end
      in ['delete', namespace]
        delete(service:, namespace:)
      in ['delete', namespace, namespace_name]
        delete(service:, namespace: (namespace unless namespace.empty?), namespace_name:)
      else
        raise ArgumentError, 'Usage: cloud_namespace.rb create|delete <namespace> [namespace-name]'
      end
    end

    # Emit connection details incrementally so CI can clean up after a later provisioning failure.
    def create(
      service:,
      env:,
      output:,
      monotonic: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
      sleeper: ->(duration) { Kernel.sleep(duration) }
    )
      namespace_name = "sdk-ruby-ci-#{env.fetch('GITHUB_RUN_ID')}-#{env.fetch('GITHUB_RUN_ATTEMPT')}"
      operation_id = SecureRandom.uuid

      # Record the deterministic name first so cleanup runs even if the create response is lost.
      output.puts("namespace_name=#{namespace_name}")
      output.flush
      result = service.create_namespace(
        Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceRequest.new(
          spec: Temporalio::Api::Cloud::Namespace::V1::NamespaceSpec.new(
            name: namespace_name,
            regions: [CLOUD_REGION],
            retention_days: 1,
            mtls_auth: Temporalio::Api::Cloud::Namespace::V1::MtlsAuthSpec.new(
              accepted_client_ca: File.binread(env.fetch('TEMPORAL_CLOUD_CLIENT_CA_PATH')),
              enabled: true
            )
          ),
          async_operation_id: operation_id
        ),
        rpc_options: rpc_options
      )

      output.puts("namespace=#{result.namespace}")
      output.flush
      wait_for_operation(service, result.async_operation, monotonic:, sleeper:)

      namespace = service.get_namespace(
        Temporalio::Api::Cloud::CloudService::V1::GetNamespaceRequest.new(namespace: result.namespace),
        rpc_options: rpc_options
      ).namespace
      address = namespace.endpoints&.mtls_grpc_address
      raise "Cloud namespace #{result.namespace} did not provide an mTLS endpoint" if address.nil? || address.empty?

      output.puts("address=#{address}")
      output.flush
    end

    # Read the latest resource version because Cloud uses optimistic concurrency for deletion.
    def delete(
      service:,
      namespace: nil,
      namespace_name: nil,
      monotonic: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
      sleeper: ->(duration) { Kernel.sleep(duration) }
    )
      namespace ||= resolve_namespace(service, namespace_name, monotonic:, sleeper:)
      return unless namespace

      existing_response = ignore_not_found do
        service.get_namespace(
          Temporalio::Api::Cloud::CloudService::V1::GetNamespaceRequest.new(namespace:),
          rpc_options: rpc_options
        )
      end
      return unless existing_response

      result = ignore_not_found do
        service.delete_namespace(
          Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceRequest.new(
            namespace:,
            resource_version: existing_response.namespace.resource_version,
            async_operation_id: SecureRandom.uuid
          ),
          rpc_options: rpc_options
        )
      end
      return unless result

      wait_for_operation(service, result.async_operation, monotonic:, sleeper:)
    end

    # Honor the server's polling interval to avoid throttling the Cloud Operations API.
    def wait_for_operation(
      service,
      operation,
      monotonic: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
      sleeper: ->(duration) { Kernel.sleep(duration) }
    )
      deadline = monotonic.call + OPERATION_TIMEOUT_SECONDS
      loop do
        remaining = deadline - monotonic.call
        raise Timeout::Error, "Timed out waiting for Cloud operation #{operation.id}" if remaining <= 0

        operation = service.get_async_operation(
          Temporalio::Api::Cloud::CloudService::V1::GetAsyncOperationRequest.new(
            async_operation_id: operation.id
          ),
          rpc_options: rpc_options(timeout: [RPC_TIMEOUT_SECONDS, remaining].min)
        ).async_operation
        return if operation.state == :STATE_FULFILLED

        if FAILED_OPERATION_STATES.include?(operation.state)
          state = operation.state.to_s.delete_prefix('STATE_').downcase
          raise "Cloud operation #{operation.id} #{state}: #{operation.failure_reason}"
        end

        now = monotonic.call
        raise Timeout::Error, "Timed out waiting for Cloud operation #{operation.id}" if now >= deadline

        duration = operation.check_duration
        delay = duration ? duration.seconds + (duration.nanos / 1_000_000_000.0) : 1
        sleeper.call([delay, 1].max.clamp(0, deadline - now))
      end
    end

    private

    def cloud_service(env)
      Temporalio::Client::Connection.new(
        target_host: CLOUD_API_TARGET,
        api_key: env.fetch('TEMPORAL_CLIENT_CLOUD_API_KEY'),
        rpc_metadata: {
          'temporal-cloud-api-version' => env.fetch('TEMPORAL_CLIENT_CLOUD_API_VERSION')
        }
      ).cloud_service
    end

    def resolve_namespace(service, namespace_name, monotonic:, sleeper:)
      raise ArgumentError, 'Namespace or namespace name required for deletion' unless namespace_name

      deadline = monotonic.call + RPC_TIMEOUT_SECONDS
      loop do
        result = service.get_namespaces(
          Temporalio::Api::Cloud::CloudService::V1::GetNamespacesRequest.new(name: namespace_name),
          rpc_options: rpc_options
        )
        namespace = result.namespaces.find { |candidate| candidate.spec.name == namespace_name }
        return namespace.namespace if namespace

        remaining = deadline - monotonic.call
        return nil if remaining <= 0

        sleeper.call([5, remaining].min)
      end
    end

    def ignore_not_found
      yield
    rescue Temporalio::Error::RPCError => e
      raise unless e.code == Temporalio::Error::RPCError::Code::NOT_FOUND

      nil
    end

    def rpc_options(timeout: RPC_TIMEOUT_SECONDS)
      Temporalio::Client::RPCOptions.new(timeout:, override_retry: true)
    end
  end
end

CloudNamespace.run(ARGV) if $PROGRAM_NAME == __FILE__
