# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'temporalio/contrib/aws/lambda_worker'
require 'temporalio/contrib/open_telemetry'
require 'temporalio/converters/payload_codec'
require 'temporalio/worker/workflow_replayer'
require 'test'

module Contrib
  module Aws
    class LambdaWorkerIntegrationTest < Test
      LambdaWorker = Temporalio::Contrib::Aws::LambdaWorker
      Context = Struct.new(:aws_request_id, :invoked_function_arn) do
        def get_remaining_time_in_millis # rubocop:disable Naming/AccessorMethodName
          30_000
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
          context = Temporalio::Activity::Context.current
          @attempts << context.info.attempt
          if context.info.attempt == 1
            context.cancellation.wait
            context.cancellation.check!
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

      class OverridePlugin < Temporalio::SimplePlugin
        def initialize
          super(name: 'override-lambda')
        end

        def configure_worker(options)
          options.with(
            deployment_options: Temporalio::Worker.default_deployment_options,
            identity: 'wrong', disable_eager_activity_execution: false
          )
        end

        def connect_client(options, next_call)
          next_call.call(options.with(identity: 'wrong'))
        end
      end

      class WorkerOnlyPlugin
        include Temporalio::Worker::Plugin

        def name
          'lambda-worker-only'
        end

        def configure_worker(options)
          options.with(deployment_options: Temporalio::Worker.default_deployment_options,
                       identity: 'wrong', disable_eager_activity_execution: false)
        end

        def run_worker(options, next_call)
          next_call.call(options.with(cancellation: Temporalio::Cancellation.new))
        end

        def configure_workflow_replayer(options)
          options
        end

        def with_workflow_replay_worker(options, next_call)
          next_call.call(options)
        end
      end

      def test_lambda_warm_resume_and_replay
        assert_warm_resume(Temporalio::VersioningBehavior::PINNED)
        assert_warm_resume(Temporalio::VersioningBehavior::AUTO_UPGRADE)
      end

      def test_lambda_composes_tracing_with_an_application_shutdown_hook
        exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
        provider = OpenTelemetry::SDK::Trace::TracerProvider.new
        provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
        tracing = Temporalio::SimplePlugin.new(
          name: 'application-tracing',
          client_interceptors: [
            Temporalio::Contrib::OpenTelemetry::TracingInterceptor.new(provider.tracer('temporal-ruby'))
          ]
        )
        budgets = []
        flush = lambda do |remaining|
          budgets << remaining
          provider.force_flush(timeout: remaining) if remaining.positive?
        end
        assert_warm_resume(Temporalio::VersioningBehavior::PINNED, plugins: [tracing], shutdown_hooks: [flush])

        assert_equal 2, budgets.length
        budgets.each { |remaining| assert_operator remaining, :>, 0 }
        assert(exporter.finished_spans.any? { |span| span.name == 'RunActivity:GreetingActivity' })
        provider.tracer('test').in_span('after-invocations') { |span| span.add_event('still-active') }
        assert_equal 'after-invocations', exporter.finished_spans.last.name
      ensure
        provider&.shutdown
      end

      def assert_warm_resume(behavior, plugins: [], shutdown_hooks: [])
        timers = Queue.new
        clients = []
        workers = []
        task_queue = "lambda-#{SecureRandom.uuid}"
        version = Temporalio::WorkerDeploymentVersion.new(deployment_name: task_queue, build_id: 'v1')
        defaults = LambdaWorker.send(:_default_dependencies)
        handler = LambdaWorker.send(
          :_define, version,
          options: LambdaWorker::Options.new(
            task_queue:, workflows: [WaitingWorkflow], activities: [GreetingActivity],
            default_versioning_behavior: behavior,
            plugins: [OverridePlugin.new] + plugins, shutdown_hooks:,
            worker_options: { graceful_shutdown_period: 0, plugins: [WorkerOnlyPlugin.new] }
          ),
          dependencies: defaults.merge(
            load_client_options: lambda do |_path|
              [[env.client.connection.target_host, env.client.namespace],
               env.client.connection.options.to_h.except(:target_host, :payload_limits)]
            end,
            connect_client: lambda do |*args, **kwargs|
              defaults.fetch(:connect_client).call(*args, **kwargs).tap { |client| clients << client }
            end,
            create_worker: lambda do |**kwargs|
              defaults.fetch(:create_worker).call(**kwargs).tap { |worker| workers << worker }
            end,
            start_shutdown_timer: lambda do |_delay, &cancel|
              timers << cancel
              nil
            end
          )
        )
        handle = env.client.workflow_handle(SecureRandom.uuid)
        invoke(handler, timers) do
          wait_deployment(version)
          env.client.start_workflow(
            WaitingWorkflow, 'Ruby', id: handle.id, task_queue:,
                                     versioning_override: Temporalio::VersioningOverride::Pinned.new(version)
          )
          assert handle.query(WaitingWorkflow.ready)
        end
        assert workers.first._bridge_worker.finalized?
        refute clients.first.connection.connected?
        handle.signal(:finish)
        invoke(handler, timers) { assert_equal 'Hello, Ruby!', handle.result }
        assert_equal 2, workers.length
        refute_equal clients[0].connection.identity, clients[1].connection.identity
        workers.each do |worker|
          assert worker._bridge_worker.finalized?
          assert_equal version, worker.options.deployment_options.version
          assert worker.options.deployment_options.use_worker_versioning
          assert_equal behavior, worker.options.deployment_options.default_versioning_behavior
          assert worker.options.disable_eager_activity_execution
          refute_equal 'wrong', worker.options.identity
        end
        replayer = Temporalio::Worker::WorkflowReplayer.new(workflows: [WaitingWorkflow])
        replayer.replay_workflow(handle.fetch_history)
      ensure
        begin
          handle&.terminate
        rescue Temporalio::Error::RPCError => e
          raise unless e.code == Temporalio::Error::RPCError::Code::NOT_FOUND
        end
      end

      def test_lambda_finalizes_when_run_plugin_fails
        worker = Temporalio::Worker.new(
          client: env.client, task_queue: SecureRandom.uuid, activities: [GreetingActivity],
          plugins: [
            Temporalio::SimplePlugin.new(name: 'fail-run', run_context: ->(_options, _next) { raise 'run failed' })
          ]
        )
        assert_raises(RuntimeError) { worker.run }
        worker._close
        assert worker._bridge_worker.finalized?
        worker._close
      end

      def test_lambda_finalizes_after_partial_worker_initialization
        client = Temporalio::Client.new(
          connection: env.client.connection, namespace: env.client.namespace,
          data_converter: Temporalio::Converters::DataConverter.new(
            payload_codec: Temporalio::Converters::PayloadCodec.new
          )
        )
        worker = Temporalio::Worker.allocate
        error = assert_raises(ArgumentError) do
          worker.send(
            :initialize,
            client:, task_queue: SecureRandom.uuid, workflows: [WaitingWorkflow],
            workflow_payload_codec_thread_pool: nil
          )
        end
        assert_includes error.message, 'payload codec thread pool'
        assert worker._bridge_worker.finalized?
      end

      def test_lambda_canceled_activity_retries_on_next_invocation
        timers = Queue.new
        attempts = Queue.new
        task_queue = SecureRandom.uuid
        version = Temporalio::WorkerDeploymentVersion.new(deployment_name: task_queue, build_id: 'v1')
        defaults = LambdaWorker.send(:_default_dependencies)
        handler = LambdaWorker.send(
          :_define, version,
          options: LambdaWorker::Options.new(
            task_queue:, workflows: [RetryingWorkflow], activities: [RetryingActivity.new(attempts)],
            worker_options: { graceful_shutdown_period: 0 }
          ),
          dependencies: defaults.merge(
            load_client_options: lambda do |_path|
              [[env.client.connection.target_host, env.client.namespace],
               env.client.connection.options.to_h.except(:target_host, :payload_limits)]
            end,
            start_shutdown_timer: lambda do |_delay, &cancel|
              timers << cancel
              nil
            end
          )
        )
        handle = env.client.workflow_handle(SecureRandom.uuid)
        invoke(handler, timers) do
          wait_deployment(version)
          env.client.start_workflow(
            RetryingWorkflow, 'retried',
            id: handle.id, task_queue:,
            versioning_override: Temporalio::VersioningOverride::Pinned.new(version)
          )
          assert_equal 1, attempts.pop
        end
        invoke(handler, timers) { assert_equal 'retried', handle.result }
        assert_equal 2, attempts.pop
      ensure
        begin
          handle&.terminate
        rescue Temporalio::Error::RPCError => e
          raise unless e.code == Temporalio::Error::RPCError::Code::NOT_FOUND
        end
      end

      private

      def wait_deployment(version)
        assert_eventually do
          response = env.client.workflow_service.describe_worker_deployment_version(
            Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentVersionRequest.new(
              namespace: env.client.namespace, version: version.to_canonical_string
            )
          )
          # Workflow and activity pollers register separately; deployment visibility alone can race the first start.
          queues = response.worker_deployment_version_info.task_queue_infos
          %i[TASK_QUEUE_TYPE_WORKFLOW TASK_QUEUE_TYPE_ACTIVITY].each do |type|
            assert(queues.any? { |queue| queue.name == version.deployment_name && queue.type == type })
          end
        rescue Temporalio::Error::RPCError => e
          raise unless e.code == Temporalio::Error::RPCError::Code::NOT_FOUND

          flunk 'Deployment not registered yet'
        end
      end

      def invoke(handler, timers, &)
        invocation = Thread.new { handler.call({}, Context.new(SecureRandom.uuid, 'arn:local')) }
        cancel = Timeout.timeout(30) { timers.pop }
        Timeout.timeout(30, &)
      ensure
        cancel&.call
        Timeout.timeout(30) { invocation&.value }
      end
    end
  end
end
