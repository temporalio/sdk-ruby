# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'set'
require 'temporalio/contrib/open_telemetry'
require 'test'

module Contrib
  class OpenTelemetryTest < Test
    class TestActivity < Temporalio::Activity::Definition
      def initialize(tracer)
        @tracer = tracer
      end

      def execute(scenario)
        case scenario.to_sym
        when :fail_first_attempt
          raise 'Intentional activity failure' if Temporalio::Activity::Context.current.info.attempt == 1

          @tracer.in_span('custom-activity-span') { 'activity-done' }
        else
          raise NotImplementedError
        end
      end
    end

    class TestWorkflow < Temporalio::Workflow::Definition
      def execute(scenario)
        case scenario.to_sym
        when :complete
          'workflow-done'
        when :fail
          raise Temporalio::Error::ApplicationError, 'Intentional workflow failure'
        when :fail_task
          raise 'Intentional workflow task failure'
        when :wait_on_signal
          Temporalio::Workflow.wait_condition { @finish }
          'workflow-done'
        when :continue_as_new
          Temporalio::Contrib::OpenTelemetry::Workflow.with_completed_span('custom-can-span') do
            raise Temporalio::Workflow::ContinueAsNewError, :complete
          end
        else
          raise NotImplementedError
        end
      end

      workflow_signal
      def signal(scenario)
        case scenario.to_sym
        when :complete
          # Do nothng
        when :fail
          raise Temporalio::Error::ApplicationError, 'Intentional signal failure'
        when :fail_task
          raise 'Intentional signal task failure'
        when :mark_finished
          @finish = true
        else
          raise NotImplementedError
        end
      end

      workflow_query
      def query(scenario)
        case scenario.to_sym
        when :complete
          'query-done'
        when :fail
          raise 'Intentional query failure'
        else
          raise NotImplementedError
        end
      end

      workflow_update
      def update(scenario)
        case scenario.to_sym
        when :complete
          'update-done'
        when :fail
          raise Temporalio::Error::ApplicationError, 'Intentional update failure'
        when :fail_task
          raise 'Intentional update task failure'
        when :call_activity
          # Do it in a custom span
          Temporalio::Contrib::OpenTelemetry::Workflow.with_completed_span(
            'custom-workflow-span', attributes: { 'foo' => 'bar' }
          ) do
            Temporalio::Workflow.execute_activity(TestActivity, :fail_first_attempt, start_to_close_timeout: 30)
          end
        when :call_local_activity
          # Do it in a custom span
          Temporalio::Contrib::OpenTelemetry::Workflow.with_completed_span(
            'custom-workflow-span', attributes: { 'baz' => 'qux' }
          ) do
            Temporalio::Workflow.execute_local_activity(TestActivity, :fail_first_attempt, start_to_close_timeout: 30)
          end
        when :child_workflow_child_signal
          handle = Temporalio::Workflow.start_child_workflow(TestWorkflow, :wait_on_signal)
          handle.signal(TestWorkflow.signal, :mark_finished)
          [handle.id, handle.first_execution_run_id, handle.result]
        when :child_workflow_external_signal
          handle = Temporalio::Workflow.start_child_workflow(TestWorkflow, :wait_on_signal)
          Temporalio::Workflow.external_workflow_handle(handle.id).signal(TestWorkflow.signal, :mark_finished)
          [handle.id, handle.first_execution_run_id, handle.result]
        else
          raise NotImplementedError
        end
      end

      workflow_update_validator(:update_with_validator)
      def validate_update_with_validator(scenario)
        case scenario.to_sym
        when :complete
          # Do nothing
        when :fail
          raise Temporalio::Error::ApplicationError, 'Intentional update validator failure'
        else
          raise NotImplementedError
        end
      end

      workflow_update
      def update_with_validator(scenario)
        case scenario.to_sym
        when :complete
          'update-with-validator-done'
        else
          raise NotImplementedError
        end
      end
    end

    def init_tracer_and_exporter
      exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
      tracer_provider = OpenTelemetry::SDK::Trace::TracerProvider.new
      tracer_provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
      tracer = tracer_provider.tracer('test-tracer')
      [tracer, exporter]
    end

    def trace(
      tracer_and_exporter: init_tracer_and_exporter,
      always_create_workflow_spans: false,
      check_root: true,
      &
    )
      tracer, exporter = tracer_and_exporter

      # Make client with interceptors
      interceptor = Temporalio::Contrib::OpenTelemetry::TracingInterceptor.new(
        tracer, always_create_workflow_spans:
      )
      new_options = env.client.options.with(interceptors: [interceptor])
      client = Temporalio::Client.new(**new_options.to_h) # steep:ignore

      # Run all in one outer span
      tracer_and_exporter.first.in_span('root') do
        yield client
      end

      # Convert spans, confirm there is only the outer, and return children
      spans = ExpectedSpan.from_span_data(exporter.finished_spans)
      if check_root
        assert_equal 1, spans.size
        assert_equal 'root', spans.first&.name
      end
      spans.first
    end

    def trace_workflow(
      scenario,
      tracer_and_exporter: init_tracer_and_exporter,
      start_with_untraced_client: false,
      always_create_workflow_spans: false,
      check_root: true,
      &
    )
      trace(tracer_and_exporter:, always_create_workflow_spans:, check_root:) do |client|
        # Must capture and attach outer context
        outer_context = OpenTelemetry::Context.current
        attach_token = nil
        execute_workflow(
          TestWorkflow,
          scenario,
          client:,
          activities: [TestActivity.new(tracer_and_exporter.first)],
          # Have to reattach outer context inside worker run to check outer span
          on_worker_run: proc { attach_token = OpenTelemetry::Context.attach(outer_context) },
          start_workflow_client: start_with_untraced_client ? env.client : client
        ) do |handle|
          yield handle
        ensure
          OpenTelemetry::Context.detach(attach_token)
        end
      end
    end

    def test_simple_successes
      exp_root = ExpectedSpan.new(name: 'root')
      history = nil
      act_root = trace_workflow(:wait_on_signal) do |handle|
        exp_cl_attrs = { 'temporalWorkflowID' => handle.id }
        exp_run_attrs = exp_cl_attrs.merge({ 'temporalRunID' => handle.result_run_id })
        exp_start_wf = exp_root.add_child(name: 'StartWorkflow:TestWorkflow', attributes: exp_cl_attrs)
        exp_run_wf = exp_start_wf.add_child(name: 'RunWorkflow:TestWorkflow', attributes: exp_run_attrs)

        # Basic query
        exp_query = exp_root.add_child(name: 'QueryWorkflow:query', attributes: exp_cl_attrs)
        exp_start_wf.add_child(name: 'HandleQuery:query', attributes: exp_run_attrs, links: [exp_query])
        assert_equal 'query-done', handle.query(TestWorkflow.query, :complete)

        # Basic update
        exp_update = exp_root.add_child(name: 'StartWorkflowUpdate:update',
                                        attributes: exp_cl_attrs.merge({ 'temporalUpdateID' => 'my-update-id' }))
        exp_start_wf.add_child(name: 'HandleUpdate:update',
                               attributes: exp_run_attrs.merge({ 'temporalUpdateID' => 'my-update-id' }),
                               links: [exp_update])
        assert_equal 'update-done', handle.execute_update(TestWorkflow.update, :complete, id: 'my-update-id')

        # Basic update with validator
        exp_update2 = exp_root.add_child(name: 'StartWorkflowUpdate:update_with_validator',
                                         attributes: exp_cl_attrs.merge({ 'temporalUpdateID' => 'my-update-id2' }))
        exp_start_wf.add_child(name: 'ValidateUpdate:update_with_validator',
                               attributes: exp_run_attrs.merge({ 'temporalUpdateID' => 'my-update-id2' }),
                               links: [exp_update2])
        exp_start_wf.add_child(name: 'HandleUpdate:update_with_validator',
                               attributes: exp_run_attrs.merge({ 'temporalUpdateID' => 'my-update-id2' }),
                               links: [exp_update2])
        assert_equal 'update-with-validator-done',
                     handle.execute_update(TestWorkflow.update_with_validator, :complete, id: 'my-update-id2')

        # Basic signal
        exp_signal = exp_root.add_child(name: 'SignalWorkflow:signal', attributes: exp_cl_attrs)
        exp_start_wf.add_child(name: 'HandleSignal:signal', attributes: exp_run_attrs, links: [exp_signal])
        handle.signal(TestWorkflow.signal, :mark_finished)

        # Workflow complete
        exp_run_wf.add_child(name: 'CompleteWorkflow:TestWorkflow', attributes: exp_run_attrs)
        assert_equal 'workflow-done', handle.result
        history = handle.fetch_history
      end
      assert_equal exp_root.to_s_indented, act_root.to_s_indented

      # Run in replayer with a tracer and confirm nothing comes up because it's all replay
      act_replay_root = trace do |client|
        replayer = Temporalio::Worker::WorkflowReplayer.new(
          workflows: [TestWorkflow],
          interceptors: client.options.interceptors # steep:ignore
        )
        replayer.replay_workflow(history || raise)
      end
      assert_equal ExpectedSpan.new(name: 'root').to_s_indented, act_replay_root.to_s_indented
    end

    def test_handler_failures
      exp_root = ExpectedSpan.new(name: 'root')
      act_root = trace_workflow(:wait_on_signal) do |handle|
        exp_cl_attrs = { 'temporalWorkflowID' => handle.id }
        exp_run_attrs = exp_cl_attrs.merge({ 'temporalRunID' => handle.result_run_id })
        exp_start_wf = exp_root.add_child(name: 'StartWorkflow:TestWorkflow', attributes: exp_cl_attrs)
        exp_start_wf.add_child(name: 'RunWorkflow:TestWorkflow', attributes: exp_run_attrs)

        # Basic query
        exp_query = exp_root.add_child(name: 'QueryWorkflow:query', attributes: exp_cl_attrs,
                                       exception_message: 'Intentional query failure')
        exp_start_wf.add_child(name: 'HandleQuery:query', attributes: exp_run_attrs, links: [exp_query])
                    .add_child(name: 'FailHandleQuery:query', attributes: exp_run_attrs,
                               exception_message: 'Intentional query failure')
        err = assert_raises(Temporalio::Error::WorkflowQueryFailedError) do
          handle.query(TestWorkflow.query, :fail)
        end
        assert_equal 'Intentional query failure', err.message

        # Basic update
        exp_update = exp_root.add_child(name: 'StartWorkflowUpdate:update',
                                        attributes: exp_cl_attrs.merge({ 'temporalUpdateID' => 'my-update-id' }))
        exp_start_wf.add_child(name: 'HandleUpdate:update',
                               attributes: exp_run_attrs.merge({ 'temporalUpdateID' => 'my-update-id' }),
                               links: [exp_update])
                    .add_child(name: 'FailHandleUpdate:update',
                               attributes: exp_run_attrs.merge({ 'temporalUpdateID' => 'my-update-id' }),
                               exception_message: 'Intentional update failure')
        err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
          handle.execute_update(TestWorkflow.update, :fail, id: 'my-update-id')
        end
        assert_equal 'Intentional update failure', err.cause.message

        # Basic update with validator
        exp_update2 = exp_root.add_child(name: 'StartWorkflowUpdate:update_with_validator',
                                         attributes: exp_cl_attrs.merge({ 'temporalUpdateID' => 'my-update-id2' }))
        exp_start_wf.add_child(name: 'ValidateUpdate:update_with_validator',
                               attributes: exp_run_attrs.merge({ 'temporalUpdateID' => 'my-update-id2' }),
                               links: [exp_update2])
                    .add_child(name: 'FailValidateUpdate:update_with_validator',
                               attributes: exp_run_attrs.merge({ 'temporalUpdateID' => 'my-update-id2' }),
                               exception_message: 'Intentional update validator failure')
        err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
          handle.execute_update(TestWorkflow.update_with_validator, :fail, id: 'my-update-id2')
        end
        assert_equal 'Intentional update validator failure', err.cause.message

        # Basic signal, where failure fails the workflow
        exp_signal = exp_root.add_child(name: 'SignalWorkflow:signal', attributes: exp_cl_attrs)
        exp_start_wf.add_child(name: 'HandleSignal:signal', attributes: exp_run_attrs, links: [exp_signal])
                    .add_child(name: 'FailHandleSignal:signal', attributes: exp_run_attrs,
                               exception_message: 'Intentional signal failure')
        handle.signal(TestWorkflow.signal, :fail)

        # Workflow complete
        err = assert_raises(Temporalio::Error::WorkflowFailedError) do
          handle.result
        end
        assert_equal 'Intentional signal failure', err.cause.message
      end
      assert_equal exp_root.to_s_indented, act_root.to_s_indented
    end

    def test_activity
      exp_root = ExpectedSpan.new(name: 'root')
      act_root = trace_workflow(:wait_on_signal) do |handle|
        exp_cl_attrs = { 'temporalWorkflowID' => handle.id }
        exp_run_attrs = exp_cl_attrs.merge({ 'temporalRunID' => handle.result_run_id })
        exp_start_wf = exp_root.add_child(name: 'StartWorkflow:TestWorkflow', attributes: exp_cl_attrs)
        exp_start_wf.add_child(name: 'RunWorkflow:TestWorkflow', attributes: exp_run_attrs)

        # Wait for task completion so update isn't accidentally first before run
        assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }

        # Update calls activity inside custom span and that activity fails on first attempt
        exp_update = exp_root.add_child(name: 'StartWorkflowUpdate:update',
                                        attributes: exp_cl_attrs.merge({ 'temporalUpdateID' => 'my-update-id' }))
        exp_start_act = exp_start_wf.add_child(
          name: 'HandleUpdate:update',
          attributes: exp_run_attrs.merge({ 'temporalUpdateID' => 'my-update-id' }),
          links: [exp_update]
        )
                                    .add_child(name: 'custom-workflow-span',
                                               attributes: exp_run_attrs.merge({ 'foo' => 'bar' }))
                                    .add_child(name: 'StartActivity:TestActivity', attributes: exp_run_attrs)
        # Two run activity calls because first one fails
        exp_start_act.add_child(
          name: 'RunActivity:TestActivity',
          attributes: exp_run_attrs.merge({ 'temporalActivityID' => '1' }),
          exception_message: 'Intentional activity failure'
        )
        exp_start_act.add_child(
          name: 'RunActivity:TestActivity',
          attributes: exp_run_attrs.merge({ 'temporalActivityID' => '1' })
        ).add_child(name: 'custom-activity-span')
        assert_equal 'activity-done', handle.execute_update(TestWorkflow.update, :call_activity, id: 'my-update-id')

        # Local activity too
        exp_update = exp_root.add_child(name: 'StartWorkflowUpdate:update',
                                        attributes: exp_cl_attrs.merge({ 'temporalUpdateID' => 'my-update-id2' }))
        exp_start_act = exp_start_wf.add_child(
          name: 'HandleUpdate:update',
          attributes: exp_run_attrs.merge({ 'temporalUpdateID' => 'my-update-id2' }),
          links: [exp_update]
        )
                                    .add_child(name: 'custom-workflow-span',
                                               attributes: exp_run_attrs.merge({ 'baz' => 'qux' }))
                                    .add_child(name: 'StartActivity:TestActivity', attributes: exp_run_attrs)
        # Two run activity calls because first one fails
        exp_start_act.add_child(
          name: 'RunActivity:TestActivity',
          attributes: exp_run_attrs.merge({ 'temporalActivityID' => '2' }),
          exception_message: 'Intentional activity failure'
        )
        exp_start_act.add_child(
          name: 'RunActivity:TestActivity',
          attributes: exp_run_attrs.merge({ 'temporalActivityID' => '2' })
        ).add_child(name: 'custom-activity-span')
        assert_equal 'activity-done',
                     handle.execute_update(TestWorkflow.update, :call_local_activity, id: 'my-update-id2')
      end
      assert_equal exp_root.to_s_indented, act_root.to_s_indented
    end

    def test_client_fail
      # Workflow start fail
      exp_root = ExpectedSpan.new(name: 'root')
      act_root = trace do |client|
        # Will fail with unknown search attribute
        err = assert_raises(Temporalio::Error::RPCError) do
          client.start_workflow(
            'does-not-exist',
            id: 'does-not-exist', task_queue: 'does-not-exist',
            search_attributes: Temporalio::SearchAttributes.new(
              {
                Temporalio::SearchAttributes::Key.new(
                  'does-not-exist', Temporalio::SearchAttributes::IndexedValueType::TEXT
                ) => 'does-not-exist'
              }
            )
          )
        end
        exp_root.add_child(name: 'StartWorkflow:does-not-exist',
                           attributes: { 'temporalWorkflowID' => 'does-not-exist' },
                           exception_message: err.message)
      end
      assert_equal exp_root.to_s_indented, act_root.to_s_indented

      # Workflow update fail
      exp_root = ExpectedSpan.new(name: 'root')
      act_root = trace do |client|
        err = assert_raises(Temporalio::Error::RPCError) do
          client.workflow_handle('does-not-exist').execute_update('does-not-exist', id: 'my-update-id')
        end
        exp_root.add_child(name: 'StartWorkflowUpdate:does-not-exist',
                           attributes: { 'temporalWorkflowID' => 'does-not-exist',
                                         'temporalUpdateID' => 'my-update-id' },
                           exception_message: err.message)
      end
      assert_equal exp_root.to_s_indented, act_root.to_s_indented
    end

    def test_child_and_external
      # We have to test child signal and external signal separately because sending both back-to-back can result in
      # rare cases where one is delivered before the other (yes, even if you wait on the first to get an initiated
      # event)
      %i[child_workflow_child_signal child_workflow_external_signal].each do |scenario|
        exp_root = ExpectedSpan.new(name: 'root')
        act_root = trace_workflow(:wait_on_signal) do |handle|
          exp_cl_attrs = { 'temporalWorkflowID' => handle.id }
          exp_run_attrs = exp_cl_attrs.merge({ 'temporalRunID' => handle.result_run_id })
          exp_start_wf = exp_root.add_child(name: 'StartWorkflow:TestWorkflow', attributes: exp_cl_attrs)
          exp_start_wf.add_child(name: 'RunWorkflow:TestWorkflow', attributes: exp_run_attrs)

          # Wait for task completion so update isn't accidentally first before run
          assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }

          # Update calls child and sends signals to it in two ways
          child_id, child_run_id, child_result = handle.execute_update(TestWorkflow.update,
                                                                       scenario, id: 'my-update-id')
          exp_update = exp_root.add_child(name: 'StartWorkflowUpdate:update',
                                          attributes: exp_cl_attrs.merge({ 'temporalUpdateID' => 'my-update-id' }))
          # Expected span for update
          exp_hnd_update = exp_start_wf.add_child(
            name: 'HandleUpdate:update',
            attributes: exp_run_attrs.merge({ 'temporalUpdateID' => 'my-update-id' }),
            links: [exp_update]
          )
          # Expected for children
          exp_child_run_attrs = { 'temporalWorkflowID' => child_id, 'temporalRunID' => child_run_id }
          exp_child_start = exp_hnd_update.add_child(name: 'StartChildWorkflow:TestWorkflow', attributes: exp_run_attrs)
          exp_child_start
            .add_child(name: 'RunWorkflow:TestWorkflow', attributes: exp_child_run_attrs)
            .add_child(name: 'CompleteWorkflow:TestWorkflow', attributes: exp_child_run_attrs)

          # There are cases where signal comes _before_ start and cases where signal _comes_ after and server gives us
          # no way of knowing that a child _actually_ began running, so we check whether task completed comes before
          # signal
          assert_equal 'workflow-done', child_result
          child_events = env.client.workflow_handle(child_id.to_s).fetch_history_events.to_a
          signal_comes_first = child_events.index(&:workflow_execution_signaled_event_attributes).to_i <
                               child_events.index(&:workflow_task_completed_event_attributes).to_i
          # Signal we send to the child
          exp_sig = if scenario == :child_workflow_child_signal
                      exp_hnd_update.add_child(name: 'SignalChildWorkflow:signal', attributes: exp_run_attrs)
                    else
                      exp_hnd_update.add_child(name: 'SignalExternalWorkflow:signal', attributes: exp_run_attrs)
                    end
          exp_child_start.add_child(
            name: 'HandleSignal:signal',
            attributes: exp_child_run_attrs,
            links: [exp_sig],
            insert_at: signal_comes_first ? 0 : 1
          )
        end
        assert_equal exp_root.to_s_indented, act_root.to_s_indented,
                     "Expected:\n#{exp_root.to_s_indented}\nActual:#{act_root.to_s_indented}"
      end
    end

    def test_continue_as_new
      exp_root = ExpectedSpan.new(name: 'root')
      act_root = trace_workflow(:continue_as_new) do |handle|
        exp_cl_attrs = { 'temporalWorkflowID' => handle.id }
        exp_run_attrs = exp_cl_attrs.merge({ 'temporalRunID' => handle.result_run_id })
        exp_start_wf = exp_root.add_child(name: 'StartWorkflow:TestWorkflow', attributes: exp_cl_attrs)
        exp_run_wf = exp_start_wf.add_child(name: 'RunWorkflow:TestWorkflow', attributes: exp_run_attrs)

        # Get continue as new error then get final result
        cont_err = assert_raises(Temporalio::Error::WorkflowContinuedAsNewError) { handle.result(follow_runs: false) }
        assert_equal 'workflow-done', handle.result

        exp_can_attrs = exp_cl_attrs.merge({ 'temporalRunID' => cont_err.new_run_id })
        exp_run_wf.add_child(name: 'custom-can-span', attributes: exp_run_attrs)
                  .add_child(name: 'RunWorkflow:TestWorkflow', attributes: exp_can_attrs)
                  .add_child(name: 'CompleteWorkflow:TestWorkflow', attributes: exp_can_attrs)
        exp_run_wf.add_child(name: 'CompleteWorkflow:TestWorkflow', attributes: exp_run_attrs,
                             exception_message: 'Continue as new')
      end
      assert_equal exp_root.to_s_indented, act_root.to_s_indented
    end

    def test_always_create_workflow_spans
      # Untraced client has no spans by default
      act = trace_workflow(:complete, start_with_untraced_client: true, check_root: false) do |handle|
        assert_equal 'workflow-done', handle.result
      end
      assert_empty act.children

      # Untraced client has no spans by default
      exp_root = ExpectedSpan.new(name: 'root')
      act = trace_workflow(
        :complete,
        start_with_untraced_client: true,
        always_create_workflow_spans: true,
        check_root: false
      ) do |handle|
        exp_attrs = { 'temporalWorkflowID' => handle.id, 'temporalRunID' => handle.result_run_id }
        exp_run_wf = exp_root.add_child(name: 'RunWorkflow:TestWorkflow', attributes: exp_attrs)
        exp_run_wf.add_child(name: 'CompleteWorkflow:TestWorkflow', attributes: exp_attrs)
        assert_equal 'workflow-done', handle.result
      end
      assert_equal exp_root.children.first&.to_s_indented, act.to_s_indented
    end

    ExpectedSpan = Data.define(:name, :children, :attributes, :links, :exception_message) # rubocop:disable Layout/ClassStructure

    class ExpectedSpan
      # Only returns unparented
      def self.from_span_data(all_spans)
        # Create a hash of spans by their ID
        by_id = all_spans.to_h do |span|
          [
            span.span_id,
            [
              ExpectedSpan.new(
                name: span.name,
                attributes: span.attributes,
                exception_message: span.events&.find { |e| e.name == 'exception' }&.attributes&.[]('exception.message')
              ),
              span
            ]
          ]
        end
        # Go over every span, associating children and links
        by_id.each_value do |(span, raw_span)|
          if raw_span.parent_span_id && raw_span.parent_span_id != OpenTelemetry::Trace::INVALID_SPAN_ID
            by_id[raw_span.parent_span_id].first.children << span
          end
          raw_span.links&.each do |link|
            span.links << by_id[link.span_context.span_id].first
          end
        end
        # Return only spans with no parent
        by_id.map do |_, (span, raw_span)|
          span if !raw_span.parent_span_id || raw_span.parent_span_id == OpenTelemetry::Trace::INVALID_SPAN_ID
        end.compact
      end

      def initialize(name:, children: [], attributes: {}, links: [], exception_message: nil)
        super
      end

      def add_child(name:, attributes: {}, links: [], exception_message: nil, insert_at: nil)
        span = ExpectedSpan.new(name:, attributes:, links:, exception_message:)
        if insert_at.nil?
          children << span
        else
          children.insert(insert_at, span)
        end
        span
      end

      def to_s_indented(indent: '')
        ret = "#{name} (attrs: #{attributes}"
        ret += ", links: [#{links.map(&:name).join(', ')}]" unless links.empty?
        ret += ", exception: '#{exception_message}'" if exception_message
        ret += ')'
        indent += '  '
        children.each do |child|
          ret += "\n#{indent}#{child.to_s_indented(indent:)}"
        end
        ret
      end
    end
  end
end
