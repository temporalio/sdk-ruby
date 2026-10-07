# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/env_config'

args, options = Temporalio::EnvConfig::ClientConfig.load_client_connect_options
client = Temporalio::Client.connect(*args, **options)
version = Temporalio::WorkerDeploymentVersion.new(
  deployment_name: ENV.fetch('TEMPORAL_DEPLOYMENT_NAME'),
  build_id: ENV.fetch('TEMPORAL_WORKER_BUILD_ID')
)
handle = client.start_workflow(
  'LambdaGreetingWorkflow', ARGV.first || 'Ruby',
  id: SecureRandom.uuid,
  task_queue: ENV.fetch('TEMPORAL_TASK_QUEUE'),
  versioning_override: Temporalio::VersioningOverride::Pinned.new(version),
  result_hint: String
)
puts handle.result
