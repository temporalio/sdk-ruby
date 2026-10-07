# frozen_string_literal: true

require 'temporalio/contrib/aws/lambda_worker'
require 'test'

module Contrib
  module Aws
    class LambdaWorkerIntegrationTest < Test
      LambdaWorker = Temporalio::Contrib::Aws::LambdaWorker

      class Context
        attr_reader :aws_request_id, :invoked_function_arn

        def initialize(remaining_millis: 30_000)
          @aws_request_id = SecureRandom.uuid
          @invoked_function_arn = 'arn:aws:lambda:local:function:worker'
          @remaining_millis = remaining_millis
        end

        def get_remaining_time_in_millis # rubocop:disable Naming/AccessorMethodName
          @remaining_millis
        end
      end

      class GreetingActivity < Temporalio::Activity::Definition
        def execute(name)
          "Hello, #{name}!"
        end
      end

      class WaitingWorkflow < Temporalio::Workflow::Definition
        workflow_query_attr_reader :ready

        def execute(name)
          @ready = true
          Temporalio::Workflow.wait_condition { @finish }
          Temporalio::Workflow.execute_activity(GreetingActivity, name, start_to_close_timeout: 10)
        end

        workflow_signal
        def finish
          @finish = true
        end
      end

      class RetryingActivity < Temporalio::Activity::Definition
        def initialize(attempts)
          @attempts = attempts
          super()
        end

        def execute(name)
          @attempts << Temporalio::Activity::Context.current.info.attempt
          if Temporalio::Activity::Context.current.info.attempt == 1
            Temporalio::Activity::Context.current.cancellation.wait
            Temporalio::Activity::Context.current.cancellation.check!
          end
          name
        end
      end

      class RetryingWorkflow < Temporalio::Workflow::Definition
        def execute(name)
          Temporalio::Workflow.execute_activity(
            RetryingActivity, name,
            start_to_close_timeout: 10,
            retry_policy: Temporalio::RetryPolicy.new(initial_interval: 0.01, max_interval: 0.01)
          )
        end
      end

      def test_workflow_resumes_on_a_later_lambda_invocation
        handler, version, task_queue, timers, clients, workers = real_handler(
          workflows: [WaitingWorkflow], activities: [GreetingActivity]
        )
        handle = env.client.workflow_handle(SecureRandom.uuid)
        run_invocation(handler, timers) do
          wait_until_deployment_registered(version)
          env.client.start_workflow(
            WaitingWorkflow, 'Ruby', id: handle.id, task_queue:,
                                     versioning_override: Temporalio::VersioningOverride::Pinned.new(version)
          )
          assert handle.query(WaitingWorkflow.ready)
        end
        refute clients.first.connection.connected?
        assert workers.first._bridge_worker.finalized?

        handle.signal(:finish)
        run_invocation(handler, timers) { assert_equal 'Hello, Ruby!', handle.result }

        assert_equal 2, clients.length
        assert_equal 2, workers.length
        refute_equal clients[0].connection.identity, clients[1].connection.identity
        clients.each { |client| refute client.connection.connected? }
        workers.each { |worker| assert worker._bridge_worker.finalized? }
      ensure
        terminate_workflow(handle)
      end

      def test_shutdown_activity_retries_on_a_later_lambda_invocation
        attempts = Queue.new
        handler, version, task_queue, timers, = real_handler(
          workflows: [RetryingWorkflow], activities: [RetryingActivity.new(attempts)]
        )
        handle = env.client.workflow_handle(SecureRandom.uuid)
        run_invocation(handler, timers) do
          wait_until_deployment_registered(version)
          env.client.start_workflow(
            RetryingWorkflow, 'Ruby', id: handle.id, task_queue:,
                                      versioning_override: Temporalio::VersioningOverride::Pinned.new(version)
          )
          assert_equal 1, attempts.pop
        end
        run_invocation(handler, timers) { assert_equal 'Ruby', handle.result }

        assert_equal 2, attempts.pop
      ensure
        terminate_workflow(handle)
      end

      private

      def wait_until_deployment_registered(version)
        assert_eventually do
          response = env.client.workflow_service.describe_worker_deployment(
            Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentRequest.new(
              namespace: env.client.namespace, deployment_name: version.deployment_name
            )
          )
          assert(response.worker_deployment_info.version_summaries.any? do |s|
            s.version == version.to_canonical_string
          end)
        rescue Temporalio::Error::RPCError => e
          raise unless e.code == Temporalio::Error::RPCError::Code::NOT_FOUND

          flunk 'Worker deployment is not registered yet'
        end
      end

      def real_handler(workflows:, activities:)
        task_queue = "lambda-#{SecureRandom.uuid}"
        version = Temporalio::WorkerDeploymentVersion.new(deployment_name: task_queue, build_id: 'build-1')
        timers = Queue.new
        clients = []
        workers = []
        defaults = LambdaWorker.send(:_default_dependencies)
        connect = defaults.fetch(:connect_client)
        create_worker = defaults.fetch(:create_worker)
        handler = LambdaWorker.send(
          :_define,
          version,
          options: LambdaWorker::Options.new(
            task_queue:, workflows:, activities:,
            worker_options: { graceful_shutdown_period: 0 }
          ),
          dependencies: defaults.merge(
            load_client_options: lambda do |_path|
              [[env.client.connection.target_host, env.client.namespace],
               env.client.connection.options.to_h.except(:target_host, :payload_limits)]
            end,
            connect_client: lambda do |*args, **kwargs|
              connect.call(*args, **kwargs).tap { |client| clients << client }
            end,
            create_worker: lambda do |**kwargs|
              create_worker.call(**kwargs).tap { |worker| workers << worker }
            end,
            start_shutdown_timer: lambda do |_delay, &cancel|
              timers << cancel
              nil
            end
          )
        )
        [handler, version, task_queue, timers, clients, workers]
      end

      def run_invocation(handler, timers, &block)
        invocation = Thread.new { handler.call({}, Context.new) }
        stop = Timeout.timeout(30) { timers.pop }
        Timeout.timeout(30) { block.call }
      ensure
        stop&.call
        Timeout.timeout(30) { invocation&.value }
      end

      def terminate_workflow(handle)
        handle&.terminate
      rescue Temporalio::Error::RPCError => e
        raise unless e.code == Temporalio::Error::RPCError::Code::NOT_FOUND
      end
    end
  end
end
