# frozen_string_literal: true

require 'English'
require 'opentelemetry' # This import will intentionally fail if the user does not have OTel gem available
require 'temporalio/client/interceptor'
require 'temporalio/converters/payload_converter'
require 'temporalio/worker/interceptor'

module Temporalio
  module Contrib
    module OpenTelemetry
      # Tracing interceptor to add OpenTelemetry traces to clients, activities, and workflows.
      class TracingInterceptor
        include Client::Interceptor
        include Worker::Interceptor::Activity
        include Worker::Interceptor::Workflow

        # @return [OpenTelemetry::Trace::Tracer] Tracer in use.
        attr_reader :tracer

        # Create interceptor.
        #
        # @param tracer [OpenTelemetry::Trace::Tracer] Tracer to use.
        # @param header_key [String] Temporal header name to serialize spans to/from. Most users should not change this.
        # @param propagator [Object] Propagator to use. Most users should not change this.
        # @param always_create_workflow_spans [Boolean] When false, the default, spans are only created in workflows
        #   when an overarching span from the client is present. In cases of starting a workflow elsewhere, e.g. CLI or
        #   schedules, a client-created span is not present and workflow spans will not be created. Setting this to true
        #   will create spans in workflows no matter what, but there is a risk of them being orphans since they may not
        #   have a parent span after replaying.
        def initialize(
          tracer,
          header_key: '_tracer-data',
          propagator: ::OpenTelemetry::Context::Propagation::CompositeTextMapPropagator.compose_propagators(
            [
              ::OpenTelemetry::Trace::Propagation::TraceContext::TextMapPropagator.new,
              ::OpenTelemetry::Baggage::Propagation::TextMapPropagator.new
            ]
          ),
          always_create_workflow_spans: false
        )
          @tracer = tracer
          @header_key = header_key
          @propagator = propagator
          @always_create_workflow_spans = always_create_workflow_spans
        end

        # @!visibility private
        def intercept_client(next_interceptor)
          ClientOutbound.new(self, next_interceptor)
        end

        # @!visibility private
        def intercept_activity(next_interceptor)
          ActivityInbound.new(self, next_interceptor)
        end

        # @!visibility private
        def intercept_workflow(next_interceptor)
          WorkflowInbound.new(self, next_interceptor)
        end

        # @!visibility private
        def _apply_context_to_headers(headers, context: ::OpenTelemetry::Context.current)
          carrier = {}
          @propagator.inject(carrier, context:)
          headers[@header_key] = carrier unless carrier.empty?
        end

        # @!visibility private
        def _attach_context(headers)
          context = _context_from_headers(headers)
          ::OpenTelemetry::Context.attach(context) if context
        end

        # @!visibility private
        def _context_from_headers(headers)
          carrier = headers[@header_key]
          @propagator.extract(carrier) if carrier.is_a?(Hash) && !carrier.empty?
        end

        # @!visibility private
        def _with_started_span(
          name:,
          kind:,
          attributes: nil,
          outbound_input: nil
        )
          tracer.in_span(name, attributes:, kind:) do
            _apply_context_to_headers(outbound_input.headers) if outbound_input
            yield
          end
        end

        # @!visibility private
        def _always_create_workflow_spans
          @always_create_workflow_spans
        end

        # @!visibility private
        class ClientOutbound < Client::Interceptor::Outbound
          def initialize(root, next_interceptor)
            super(next_interceptor)
            @root = root
          end

          # @!visibility private
          def start_workflow(input)
            @root._with_started_span(
              name: "StartWorkflow:#{input.workflow}",
              kind: :client,
              attributes: { 'temporalWorkflowID' => input.workflow_id },
              outbound_input: input
            ) { super }
          end

          # @!visibility private
          def start_update_with_start_workflow(input)
            @root._with_started_span(
              name: "UpdateWithStartWorkflow:#{input.update}",
              kind: :client,
              attributes: { 'temporalWorkflowID' => input.start_workflow_operation.options.id,
                            'temporalUpdateID' => input.update_id },
              outbound_input: input
            ) do
              # Also add to start headers
              if input.headers[@header_key]
                input.start_workflow_operation.options.headers[@header_key] = input.headers[@header_key]
              end
              super
            end
          end

          # @!visibility private
          def signal_with_start_workflow(input)
            @root._with_started_span(
              name: "SignalWithStartWorkflow:#{input.workflow}",
              kind: :client,
              attributes: { 'temporalWorkflowID' => input.start_workflow_operation.options.id },
              outbound_input: input
            ) do
              # Also add to start headers
              if input.headers[@header_key]
                input.start_workflow_operation.options.headers[@header_key] = input.headers[@header_key]
              end
              super
            end
          end

          # @!visibility private
          def signal_workflow(input)
            @root._with_started_span(
              name: "SignalWorkflow:#{input.signal}",
              kind: :client,
              attributes: { 'temporalWorkflowID' => input.workflow_id },
              outbound_input: input
            ) { super }
          end

          # @!visibility private
          def query_workflow(input)
            @root._with_started_span(
              name: "QueryWorkflow:#{input.query}",
              kind: :client,
              attributes: { 'temporalWorkflowID' => input.workflow_id },
              outbound_input: input
            ) { super }
          end

          # @!visibility private
          def start_workflow_update(input)
            @root._with_started_span(
              name: "StartWorkflowUpdate:#{input.update}",
              kind: :client,
              attributes: { 'temporalWorkflowID' => input.workflow_id, 'temporalUpdateID' => input.update_id },
              outbound_input: input
            ) { super }
          end
        end

        # @!visibility private
        class ActivityInbound < Worker::Interceptor::Activity::Inbound
          def initialize(root, next_interceptor)
            super(next_interceptor)
            @root = root
          end

          # @!visibility private
          def execute(input)
            @root._attach_context(input.headers)
            info = Activity::Context.current.info
            @root._with_started_span(
              name: "RunActivity:#{info.activity_type}",
              kind: :server,
              attributes: {
                'temporalWorkflowID' => info.workflow_id,
                'temporalRunID' => info.workflow_run_id,
                'temporalActivityID' => info.activity_id
              }
            ) { super }
          end
        end

        # @!visibility private
        class WorkflowInbound < Worker::Interceptor::Workflow::Inbound
          def initialize(root, next_interceptor)
            super(next_interceptor)
            @root = root
          end

          # @!visibility private
          def init(outbound)
            # Set root on storage
            Temporalio::Workflow.storage[:__temporal_opentelemetry_tracing_interceptor] = @root
            super(WorkflowOutbound.new(@root, outbound))
          end

          # @!visibility private
          def execute(input)
            @root._attach_context(Temporalio::Workflow.info.headers)
            Workflow.with_completed_span("RunWorkflow:#{Temporalio::Workflow.info.workflow_type}", kind: :server) do
              super
            ensure
              Workflow.completed_span(
                "CompleteWorkflow:#{Temporalio::Workflow.info.workflow_type}",
                kind: :internal,
                exception: $ERROR_INFO # steep:ignore
              )
            end
          end

          # @!visibility private
          def handle_signal(input)
            @root._attach_context(Temporalio::Workflow.info.headers)
            Workflow.with_completed_span(
              "HandleSignal:#{input.signal}",
              links: _links_from_headers(input.headers),
              kind: :server
            ) do
              super
            rescue Exception => e # rubocop:disable Lint/RescueException
              Workflow.completed_span("FailHandleSignal:#{input.signal}", kind: :internal, exception: e)
              raise
            end
          end

          # @!visibility private
          def handle_query(input)
            @root._attach_context(Temporalio::Workflow.info.headers)
            Workflow.with_completed_span(
              "HandleQuery:#{input.query}",
              links: _links_from_headers(input.headers),
              kind: :server,
              even_during_replay: true
            ) do
              super
            rescue Exception => e # rubocop:disable Lint/RescueException
              Workflow.completed_span(
                "FailHandleQuery:#{input.query}",
                kind: :internal,
                exception: e,
                even_during_replay: true
              )
              raise
            end
          end

          # @!visibility private
          def validate_update(input)
            @root._attach_context(Temporalio::Workflow.info.headers)
            Workflow.with_completed_span(
              "ValidateUpdate:#{input.update}",
              attributes: { 'temporalUpdateID' => input.id },
              links: _links_from_headers(input.headers),
              kind: :server,
              even_during_replay: true
            ) do
              super
            rescue Exception => e # rubocop:disable Lint/RescueException
              Workflow.completed_span(
                "FailValidateUpdate:#{input.update}",
                attributes: { 'temporalUpdateID' => input.id },
                kind: :internal,
                exception: e,
                even_during_replay: true
              )
              raise
            end
          end

          # @!visibility private
          def handle_update(input)
            @root._attach_context(Temporalio::Workflow.info.headers)
            Workflow.with_completed_span(
              "HandleUpdate:#{input.update}",
              attributes: { 'temporalUpdateID' => input.id },
              links: _links_from_headers(input.headers),
              kind: :server
            ) do
              super
            rescue Exception => e # rubocop:disable Lint/RescueException
              Workflow.completed_span(
                "FailHandleUpdate:#{input.update}",
                attributes: { 'temporalUpdateID' => input.id },
                kind: :internal,
                exception: e
              )
              raise
            end
          end

          # @!visibility private
          def _links_from_headers(headers)
            context = @root._context_from_headers(headers)
            span = ::OpenTelemetry::Trace.current_span(context) if context
            if span && span != ::OpenTelemetry::Trace::Span::INVALID
              [::OpenTelemetry::Trace::Link.new(span.context)]
            else
              []
            end
          end
        end

        # @!visibility private
        class WorkflowOutbound < Worker::Interceptor::Workflow::Outbound
          def initialize(root, next_interceptor)
            super(next_interceptor)
            @root = root
          end

          # @!visibility private
          def execute_activity(input)
            _apply_span_to_headers(input.headers,
                                   Workflow.completed_span("StartActivity:#{input.activity}", kind: :client))
            super
          end

          # @!visibility private
          def execute_local_activity(input)
            _apply_span_to_headers(input.headers,
                                   Workflow.completed_span("StartActivity:#{input.activity}", kind: :client))
            super
          end

          # @!visibility private
          def initialize_continue_as_new_error(input)
            # Just apply the current context to headers
            @root._apply_context_to_headers(input.error.headers)
            super
          end

          # @!visibility private
          def signal_child_workflow(input)
            _apply_span_to_headers(input.headers,
                                   Workflow.completed_span("SignalChildWorkflow:#{input.signal}", kind: :client))
            super
          end

          # @!visibility private
          def signal_external_workflow(input)
            _apply_span_to_headers(input.headers,
                                   Workflow.completed_span("SignalExternalWorkflow:#{input.signal}", kind: :client))
            super
          end

          # @!visibility private
          def start_child_workflow(input)
            _apply_span_to_headers(input.headers,
                                   Workflow.completed_span("StartChildWorkflow:#{input.workflow}", kind: :client))
            super
          end

          # @!visibility private
          def _apply_span_to_headers(headers, span)
            @root._apply_context_to_headers(headers, context: ::OpenTelemetry::Trace.context_with_span(span)) if span
          end
        end

        private_constant :ClientOutbound
        private_constant :ActivityInbound
        private_constant :WorkflowInbound
        private_constant :WorkflowOutbound
      end

      # Contains workflow methods that can be used for OpenTelemetry.
      module Workflow
        # Create a completed span and execute block with the span set on the context.
        #
        # @param name [String] Span name.
        # @param attributes [Hash] Span attributes. These will have workflow and run ID automatically added.
        # @param links [Array, nil] Span links.
        # @param kind [Symbol, nil] Span kind.
        # @param exception [Exception, nil] Exception to record on the span.
        # @param even_during_replay [Boolean] Set to true to record this span even during replay. Most users should
        #   never set this.
        # @yield Block to call. It is UNSAFE to expect any parameters in this block.
        # @return [Object] Result of the block.
        def self.with_completed_span(
          name,
          attributes: {},
          links: nil,
          kind: nil,
          exception: nil,
          even_during_replay: false
        )
          span = completed_span(name, attributes:, links:, kind:, exception:, even_during_replay:)
          if span
            ::OpenTelemetry::Trace.with_span(span) do # rubocop:disable Style/ExplicitBlockArgument
              # Yield with no parameters
              yield
            end
          else
            yield
          end
        end

        # Create a completed span only if not replaying (or `even_during_replay` is true).
        #
        # @note WARNING: It is UNSAFE to rely on the result of this method as it may be different/absent on replay.
        #
        # @param name [String] Span name.
        # @param attributes [Hash] Span attributes. These will have workflow and run ID automatically added.
        # @param links [Array, nil] Span links.
        # @param kind [Symbol, nil] Span kind.
        # @param exception [Exception, nil] Exception to record on the span.
        # @param even_during_replay [Boolean] Set to true to record this span even during replay. Most users should
        #   never set this.
        # @return [OpenTelemetry::Trace::Span, nil] Span if one was created. WARNING: It is UNSAFE to use this value.
        def self.completed_span(
          name,
          attributes: {},
          links: nil,
          kind: nil,
          exception: nil,
          even_during_replay: false
        )
          # Get root interceptor, which also checks if in workflow
          root = Temporalio::Workflow.storage[:__temporal_opentelemetry_tracing_interceptor] #: TracingInterceptor?
          raise 'Tracing interceptor not configured' unless root

          # Do nothing if replaying and not wanted during replay
          return nil if !even_during_replay && Temporalio::Workflow::Unsafe.replaying?

          # If there is no span on the context and the user hasn't opted in to always creating, do not create. This
          # prevents orphans if there was no span originally created from the client start-workflow call.
          if ::OpenTelemetry::Trace.current_span == ::OpenTelemetry::Trace::Span::INVALID &&
             !root._always_create_workflow_spans
            return nil
          end

          # Create attributes, adding user-defined ones
          attributes = { 'temporalWorkflowID' => Temporalio::Workflow.info.workflow_id,
                         'temporalRunID' => Temporalio::Workflow.info.run_id }.merge(attributes)

          time = Temporalio::Workflow.now.dup
          # Disable illegal call tracing because OTel asks for full exception message which uses error highlighting and
          # such which accesses File#path, and they also use loggers accessing current time
          Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled do
            # Disable durable scheduler because 1) synchronous/non-batch span processors in OTel use network (though
            # could have just used Unafe.io_enabled for this if not for the next point) and 2) OTel uses Ruby Timeout
            # which we don't want to use durable timers.
            Temporalio::Workflow::Unsafe.durable_scheduler_disabled do
              span = root.tracer.start_span(name, attributes:, links:, start_timestamp: time, kind:) # steep:ignore
              # Record exception if present
              span.record_exception(exception) if exception
              # Finish the span (returns self)
              span.finish(end_timestamp: time)
            end
          end
        end
      end
    end
  end
end
