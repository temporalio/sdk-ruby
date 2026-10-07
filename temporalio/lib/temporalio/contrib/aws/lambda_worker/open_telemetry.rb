# frozen_string_literal: true

require 'temporalio/contrib/aws/lambda_worker'
require 'temporalio/runtime'
require 'temporalio/simple_plugin'

module Temporalio
  module Contrib
    module Aws
      class LambdaWorker
        # OpenTelemetry helpers for Lambda workers.
        module OpenTelemetry
          # A normal SDK plugin that configures Temporal tracing and Core OTLP metrics for ADOT.
          #
          # WARNING: Plugins are experimental.
          class Plugin < Temporalio::SimplePlugin
            Options = Data.define(
              :tracer,
              :tracer_provider,
              :endpoint,
              :service_name,
              :metric_periodicity
            )

            # Immutable OpenTelemetry configuration resolved when the plugin is created.
            #
            # @!attribute tracer
            #   @return [Object] Tracer used by Temporal interceptors.
            # @!attribute tracer_provider
            #   @return [Object] Provider flushed after every Lambda invocation.
            # @!attribute endpoint
            #   @return [String] OTLP endpoint used for Core metrics.
            # @!attribute service_name
            #   @return [String, nil] OTel service name attached to Core metrics.
            # @!attribute metric_periodicity
            #   @return [Float, nil] Core metric export interval in seconds.
            class Options; end # rubocop:disable Lint/EmptyClass

            # @return [Options] Immutable OpenTelemetry configuration.
            attr_reader :otel_options

            # @return [Runtime] Runtime that exports Core metrics to the OTLP endpoint.
            attr_reader :runtime

            # Create an OpenTelemetry plugin for a Lambda worker.
            #
            # The application configures the OpenTelemetry SDK and exporter. This plugin only connects that provider
            # to Temporal tracing, Core metrics, and Lambda invocation shutdown.
            #
            # @param tracer [Object, nil] Tracer used by Temporal interceptors. Defaults to a tracer from
            #   `tracer_provider`.
            # @param tracer_provider [Object, nil] Provider flushed after each invocation. Defaults to the global OTel
            #   provider.
            # @param endpoint [String, nil] OTLP endpoint. Defaults to `OTEL_EXPORTER_OTLP_ENDPOINT`, then ADOT's
            #   local `http://localhost:4317` endpoint.
            # @param service_name [String, nil] Metric service name. Defaults to `OTEL_SERVICE_NAME`, then
            #   `AWS_LAMBDA_FUNCTION_NAME`, then `temporal-lambda-worker`.
            # @param metric_periodicity [Numeric, nil] Core OTLP metric export interval in seconds.
            def initialize(
              tracer: nil,
              tracer_provider: nil,
              endpoint: nil,
              service_name: nil,
              metric_periodicity: 10.0
            )
              require 'temporalio/contrib/open_telemetry'

              tracer_provider ||= ::OpenTelemetry.tracer_provider # steep:ignore NoMethod
              tracer ||= tracer_provider.tracer('temporal-ruby')
              endpoint ||= ENV.fetch('OTEL_EXPORTER_OTLP_ENDPOINT', nil)
              endpoint = 'http://localhost:4317' if endpoint.nil? || endpoint.empty?
              service_name = ENV.fetch('OTEL_SERVICE_NAME', nil) if service_name.nil? || service_name.empty?
              service_name = ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', nil) if service_name.nil? || service_name.empty?
              service_name = 'temporal-lambda-worker' if service_name.nil? || service_name.empty?
              endpoint = endpoint.dup.freeze
              service_name = service_name&.dup&.freeze
              metric_periodicity = Float(metric_periodicity) if metric_periodicity
              if metric_periodicity && (!metric_periodicity.finite? || metric_periodicity <= 0)
                raise ArgumentError, 'metric_periodicity must be finite and positive'
              end

              @otel_options = Options.new(
                tracer:,
                tracer_provider:,
                endpoint:,
                service_name:,
                metric_periodicity:
              ).freeze
              @telemetry = Runtime::TelemetryOptions.new(
                metrics: Runtime::MetricsOptions.new(
                  opentelemetry: Runtime::OpenTelemetryMetricsOptions.new(
                    url: @otel_options.endpoint,
                    metric_periodicity: @otel_options.metric_periodicity,
                    http: false
                  ),
                  attach_service_name: false,
                  global_tags: service_name ? { 'service.name' => service_name, 'service_name' => service_name } : nil
                )
              )
              @runtime = Runtime.new(telemetry: @telemetry)
              super(
                name: 'temporalio-contrib-aws-lambda-worker-opentelemetry',
                client_interceptors: [Temporalio::Contrib::OpenTelemetry::TracingInterceptor.new(@otel_options.tracer)]
              )
            end

            # Add Core OTLP metrics to each invocation's client connection.
            def connect_client(options, next_call)
              next_call.call(options.with(runtime: @runtime))
            end

            # @!visibility private
            def lambda_shutdown_hook
              @lambda_shutdown_hook ||= lambda do
                @otel_options.tracer_provider.force_flush if @otel_options.tracer_provider.respond_to?(:force_flush)
              end
            end
          end
        end
      end
    end
  end
end
