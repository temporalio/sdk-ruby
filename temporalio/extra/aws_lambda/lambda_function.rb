# frozen_string_literal: true

# rubocop:disable Style/Documentation, Style/DocumentationMethod

require 'temporalio/contrib/aws/lambda_worker'

module LambdaSample
  class GreetingActivity < Temporalio::Activity::Definition
    def execute(name)
      "Hello, #{name}!"
    end
  end

  class GreetingWorkflow < Temporalio::Workflow::Definition
    workflow_name 'LambdaGreetingWorkflow'

    def execute(name)
      Temporalio::Workflow.execute_activity(GreetingActivity, name, start_to_close_timeout: 10)
    end
  end

  VERSION = Temporalio::WorkerDeploymentVersion.new(
    deployment_name: ENV.fetch('TEMPORAL_DEPLOYMENT_NAME'),
    build_id: ENV.fetch('TEMPORAL_WORKER_BUILD_ID')
  )

  plugins = []
  if ENV['TEMPORAL_LAMBDA_OTEL'] == '1'
    require_relative 'telemetry'
    plugins << Temporalio::Contrib::Aws::LambdaWorker::OpenTelemetry::Plugin.new(metric_periodicity: 1)
  end

  WORKER = Temporalio::Contrib::Aws::LambdaWorker.define(
    VERSION,
    options: Temporalio::Contrib::Aws::LambdaWorker::Options.new(
      workflows: [GreetingWorkflow], activities: [GreetingActivity], plugins:
    )
  )
end

def lambda_handler(event:, context:)
  LambdaSample::WORKER.call(event, context)
end

# rubocop:enable Style/Documentation, Style/DocumentationMethod
