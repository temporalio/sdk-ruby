# frozen_string_literal: true

require 'opentelemetry/exporter/otlp'
require 'opentelemetry/sdk'

exporter = OpenTelemetry::Exporter::OTLP::Exporter.new(
  endpoint: ENV.fetch('OTEL_EXPORTER_OTLP_TRACES_ENDPOINT', 'http://localhost:4318/v1/traces')
)
OpenTelemetry::SDK.configure do |config|
  config.service_name = ENV.fetch('OTEL_SERVICE_NAME', ENV.fetch('AWS_LAMBDA_FUNCTION_NAME', 'temporal-lambda-worker'))
  config.add_span_processor(OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(exporter))
end
