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
  FAILED_OPERATION_STATES = %i[STATE_FAILED STATE_CANCELLED STATE_REJECTED].freeze

  class << self
    # Keep command dispatch separate so the lifecycle can run inside the repository's Ruby bundle.
    def run(args)
      case args
      in ['create']
        create
      in ['delete', namespace]
        delete(namespace)
      else
        raise ArgumentError, 'Usage: cloud_namespace.rb create|delete <namespace>'
      end
    end

    # Emit the namespace before polling so cleanup can run if provisioning later fails.
    def create
      service = cloud_service
      namespace_name = "sdk-ruby-ci-#{required_env('GITHUB_RUN_ID')}-#{required_env('GITHUB_RUN_ATTEMPT')}"
      result = service.create_namespace(
        Temporalio::Api::Cloud::CloudService::V1::CreateNamespaceRequest.new(
          spec: Temporalio::Api::Cloud::Namespace::V1::NamespaceSpec.new(
            name: namespace_name,
            replicas: [Temporalio::Api::Cloud::Namespace::V1::ReplicaSpec.new(region: CLOUD_REGION)],
            retention_days: 1,
            mtls_auth: Temporalio::Api::Cloud::Namespace::V1::MtlsAuthSpec.new(
              accepted_client_ca: File.binread(required_env('TEMPORAL_CLOUD_CLIENT_CA_PATH')),
              enabled: true
            )
          ),
          async_operation_id: SecureRandom.uuid
        )
      )
      namespace = result.namespace
      raise 'Create namespace response did not include a namespace' if namespace.nil? || namespace.empty?

      File.open(required_env('GITHUB_OUTPUT'), 'a') { |output| output.puts("namespace=#{namespace}") }
      wait_for_operation(service, result.async_operation)
    end

    # Read the current resource version because Cloud uses optimistic concurrency for deletion.
    def delete(namespace)
      service = cloud_service
      existing = service.get_namespace(
        Temporalio::Api::Cloud::CloudService::V1::GetNamespaceRequest.new(namespace:)
      ).namespace
      resource_version = existing&.resource_version
      if resource_version.nil? || resource_version.empty?
        raise "Cloud namespace #{namespace} did not include a resource version"
      end

      result = service.delete_namespace(
        Temporalio::Api::Cloud::CloudService::V1::DeleteNamespaceRequest.new(
          namespace:,
          resource_version:,
          async_operation_id: SecureRandom.uuid
        )
      )
      wait_for_operation(service, result.async_operation)
    end

    # Honor server polling guidance while bounding the overall asynchronous operation.
    def wait_for_operation(service, operation)
      operation_id = operation&.id
      raise 'Cloud operation response did not include an ID' if operation_id.nil? || operation_id.empty?

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + OPERATION_TIMEOUT_SECONDS
      loop do
        operation = service.get_async_operation(
          Temporalio::Api::Cloud::CloudService::V1::GetAsyncOperationRequest.new(
            async_operation_id: operation_id
          )
        ).async_operation
        raise "Cloud operation #{operation_id} could not be read" unless operation
        return if operation.state == :STATE_FULFILLED

        if FAILED_OPERATION_STATES.include?(operation.state)
          state = operation.state.to_s.delete_prefix('STATE_').downcase
          raise "Cloud operation #{operation_id} #{state}: #{operation.failure_reason}"
        end

        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise Timeout::Error, "Timed out waiting for Cloud operation #{operation_id}" if remaining <= 0

        duration = operation.check_duration
        delay = duration ? duration.seconds + (duration.nanos / 1_000_000_000.0) : 10
        minimum_delay = [1, remaining].min
        Kernel.sleep(delay.clamp(minimum_delay, remaining))
      end
    end

    private

    def cloud_service
      Temporalio::Client::Connection.new(
        target_host: CLOUD_API_TARGET,
        api_key: required_env('TEMPORAL_CLIENT_CLOUD_API_KEY'),
        rpc_metadata: {
          'temporal-cloud-api-version' => required_env('TEMPORAL_CLIENT_CLOUD_API_VERSION')
        }
      ).cloud_service
    end

    def required_env(name)
      value = ENV.fetch(name, '')
      return value unless value.empty?

      raise "Missing required environment variable #{name}"
    end
  end
end

CloudNamespace.run(ARGV) if $PROGRAM_NAME == __FILE__
