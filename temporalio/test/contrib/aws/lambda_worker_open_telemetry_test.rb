# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'temporalio/contrib/aws/lambda_worker'
require 'test'

module Contrib
  module Aws
    class LambdaWorkerOpenTelemetryTest < Test
      LambdaWorker = Temporalio::Contrib::Aws::LambdaWorker
      Plugin = LambdaWorker::OpenTelemetry::Plugin

      FakeTracer = Object.new.freeze

      class FakeActivity < Temporalio::Activity::Definition
        def execute; end
      end

      class FakeTracerProvider
        attr_reader :tracer_names, :flushes

        def initialize(events: nil)
          @events = events
          @tracer_names = []
          @flushes = 0
        end

        def tracer(name)
          @tracer_names << name
          FakeTracer
        end

        def force_flush
          @flushes += 1
          @events << :flush if @events
        end
      end

      class FakeInvocationContext
        attr_reader :aws_request_id, :invoked_function_arn

        def initialize
          @aws_request_id = 'request-1'
          @invoked_function_arn = 'arn:aws:lambda:test'
        end

        # AWS fixes this method name as part of the Lambda context interface.
        def get_remaining_time_in_millis # rubocop:disable Naming/AccessorMethodName
          20_000
        end
      end

      class FakeInvocationWorker
        def initialize(events)
          @events = events
        end

        def run(cancellation:)
          @events << :worker_run
          cancellation
        end
      end

      def test_plugin_configures_tracing_and_core_otlp_metrics
        provider = FakeTracerProvider.new
        plugin = with_environment(
          'OTEL_EXPORTER_OTLP_ENDPOINT' => 'http://adot:4317',
          'OTEL_SERVICE_NAME' => 'lambda-service',
          'AWS_LAMBDA_FUNCTION_NAME' => 'ignored-function-name'
        ) do
          build_plugin(tracer_provider: provider).first
        end

        assert_equal ['temporal-ruby'], provider.tracer_names
        assert_equal 'http://adot:4317', plugin.otel_options.endpoint
        assert_equal 'lambda-service', plugin.otel_options.service_name
        interceptors = plugin.options.client_interceptors
        raise 'client interceptors were not configured' unless interceptors.is_a?(Array)

        assert_instance_of Temporalio::Contrib::OpenTelemetry::TracingInterceptor,
                           interceptors.first

        metrics = plugin.instance_variable_get(:@telemetry).metrics
        assert_instance_of Temporalio::Runtime, plugin.runtime
        assert_equal 'http://adot:4317', metrics.opentelemetry.url
        assert_equal false, metrics.opentelemetry.http
        assert_equal false, metrics.attach_service_name
        assert_equal(
          { 'service.name' => 'lambda-service', 'service_name' => 'lambda-service' },
          metrics.global_tags
        )

        connection = Temporalio::Client::Connection.new(target_host: 'temporal.example:7233', lazy_connect: true)
        seen_options = connection.options
        plugin.connect_client(
          connection.options,
          lambda do |configured_options|
            seen_options = configured_options
            connection
          end
        )
        assert_equal plugin.runtime, seen_options.runtime
      end

      def test_plugin_resolves_adot_defaults_and_flushes_provider
        provider = FakeTracerProvider.new
        plugin = with_environment(
          'OTEL_EXPORTER_OTLP_ENDPOINT' => nil,
          'OTEL_SERVICE_NAME' => nil,
          'AWS_LAMBDA_FUNCTION_NAME' => 'lambda-function'
        ) do
          build_plugin(tracer_provider: provider).first
        end

        assert_equal 'http://localhost:4317', plugin.otel_options.endpoint
        assert_equal 'lambda-function', plugin.otel_options.service_name
        plugin.lambda_shutdown_hook.call
        assert_equal 1, provider.flushes
      end

      def test_plugin_flushes_after_lambda_worker_stops
        events = []
        provider = FakeTracerProvider.new(events:)
        plugin, = build_plugin(tracer_provider: provider)
        options = LambdaWorker::Options.new(
          task_queue: 'queue',
          activities: [FakeActivity],
          plugins: [plugin]
        )
        version = Temporalio::WorkerDeploymentVersion.new(deployment_name: 'lambda-worker-test', build_id: 'build-1')
        handler = LambdaWorker.send(
          :_define,
          version,
          options:,
          dependencies: {
            connect_client: ->(*_args, **_kwargs) { Object.new },
            create_worker: ->(**_kwargs) { FakeInvocationWorker.new(events) },
            start_shutdown_timer: ->(_delay, &_block) { Object.new },
            cleanup_worker: ->(_worker) { events << :worker_cleanup },
            cleanup_client: ->(_client) { events << :cleanup },
            getenv: ->(_name) {},
            readable_file: ->(_path) { false },
            cwd: -> { '/work' },
            load_client_options: ->(_path) { [['temporal.example:7233', 'namespace'], {}] }
          }
        )
        handler.call({}, FakeInvocationContext.new)

        assert_equal %i[worker_run worker_cleanup flush cleanup], events
        assert_equal 1, provider.flushes
      end

      def test_plugin_has_a_service_name_without_lambda_environment
        plugin = with_environment('OTEL_SERVICE_NAME' => nil, 'AWS_LAMBDA_FUNCTION_NAME' => nil) do
          build_plugin(tracer_provider: FakeTracerProvider.new).first
        end
        assert_equal 'temporal-lambda-worker', plugin.otel_options.service_name
      end

      def test_plugin_rejects_invalid_metric_intervals
        [0, -1, Float::NAN, Float::INFINITY].each do |metric_periodicity|
          assert_raises(ArgumentError) do
            build_plugin(tracer_provider: FakeTracerProvider.new, metric_periodicity:)
          end
        end
      end

      private

      def build_plugin(**options)
        runtime = Temporalio::Runtime.allocate
        runtime_singleton = Temporalio::Runtime.singleton_class
        runtime_singleton.send(:define_method, :new) { |**_kwargs| runtime }
        plugin = Plugin.new(**options)
        [plugin, runtime] #: [Temporalio::Contrib::Aws::LambdaWorker::OpenTelemetry::Plugin, Temporalio::Runtime]
      ensure
        runtime_singleton&.send(:remove_method, :new)
      end

      def with_environment(values)
        originals = values.each_with_object({}) { |(key, _), original| original[key] = ENV.fetch(key, nil) }
        values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
        yield
      ensure
        originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
      end
    end
  end
end
