# frozen_string_literal: true

require 'opentelemetry/sdk'
require 'temporalio/client'
require 'temporalio/contrib/open_telemetry'
require 'temporalio/error'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

class WorkerWorkflowNexusTest < Test
  # Test basic sync operation success
  class NexusSyncOperationSuccessWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      client.execute_operation('echo', 'success')
    end
  end

  def test_nexus_sync_operation_success
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"
      result = execute_workflow(NexusSyncOperationSuccessWorkflow, endpoint)
      assert_equal 'success', result
    end
  end

  # Test sync operation with handler error
  class NexusSyncOperationHandlerErrorWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      client.execute_operation('echo', 'fail')
    end
  end

  def test_nexus_sync_operation_handler_error
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        execute_workflow(NexusSyncOperationHandlerErrorWorkflow, endpoint)
      end
      assert_instance_of Temporalio::Error::NexusOperationError, err.cause
      assert_includes err.cause.message, 'nexus operation completed unsuccessfully'
    end
  end

  # Test async operation success
  class NexusAsyncOperationSuccessWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      handle = client.start_operation('workflow-operation', { 'action' => 'success' })

      # For async operations, operation_token should be present
      Temporalio::Workflow.logger.info("Operation started with token: #{handle.operation_token}")

      handle.result
    end
  end

  def test_nexus_async_operation_success
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"
      result = execute_workflow(NexusAsyncOperationSuccessWorkflow, endpoint)
      assert_equal 'success', result['result']
    end
  end

  # Test async operation failure
  class NexusAsyncOperationFailureWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      handle = client.start_operation('workflow-operation', { 'action' => 'fail' })

      # For async operations, operation_token should be present
      Temporalio::Workflow.logger.info("Operation started with token: #{handle.operation_token}")

      handle.result
    end
  end

  def test_nexus_async_operation_failure
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        execute_workflow(NexusAsyncOperationFailureWorkflow, endpoint)
      end
      assert_instance_of Temporalio::Error::NexusOperationError, err.cause
      assert_includes err.cause.message, 'nexus operation completed unsuccessfully'
    end
  end

  # Test operation handle with token (reused for both async and sync)
  class NexusOperationHandleWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :operation_token
    workflow_query_attr_reader :has_token

    def execute(endpoint, operation, input)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      handle = client.start_operation(operation, input)

      @operation_token = handle.operation_token
      @has_token = !handle.operation_token.nil?

      handle.result
    end
  end

  def test_nexus_operation_handle_async_has_token
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      execute_workflow(
        NexusOperationHandleWorkflow,
        endpoint,
        'workflow-operation',
        { 'action' => 'success' }
      ) do |handle|
        # Wait for operation to start
        assert_eventually { assert handle.query(NexusOperationHandleWorkflow.has_token) }

        token = handle.query(NexusOperationHandleWorkflow.operation_token)
        refute_nil token
        assert token.length.positive? # steep:ignore

        result = handle.result
        assert_equal 'success', result['result'] # steep:ignore
      end
    end
  end

  def test_nexus_operation_handle_sync_has_token
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      execute_workflow(NexusOperationHandleWorkflow, endpoint, 'echo', 'success') do |handle|
        # Even sync operations have tokens when using start_operation
        assert_eventually { assert handle.query(NexusOperationHandleWorkflow.has_token) }

        token = handle.query(NexusOperationHandleWorkflow.operation_token)
        refute_nil token

        result = handle.result
        assert_equal 'success', result
      end
    end
  end

  # Test operation cancellation (reused for different cancellation types)
  class NexusCancellationWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :started
    workflow_query_attr_reader :cancelled

    def execute(endpoint, cancellation_type)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')

      cancellation, cancel_proc = Temporalio::Cancellation.new
      handle = client.start_operation(
        'workflow-operation',
        { 'action' => 'wait-for-cancel' },
        cancellation_type:,
        cancellation:
      )

      @started = true

      # Wait for the operation to actually start before cancelling
      # In time-skipping mode, we need to yield to let the operation start
      Temporalio::Workflow.sleep(0.01)

      # Cancel the operation
      cancel_proc.call
      @cancelled = true

      # Yield to allow the cancel command to be processed
      Temporalio::Workflow.sleep(0.01)

      # For async operations that are cancelled, result should raise NexusOperationError
      begin
        handle.result
      rescue Temporalio::Error::NexusOperationError => e
        # Check if the cause is a CanceledError
        return { 'cancelled' => true, 'error' => e.class.name } if e.cause.is_a?(Temporalio::Error::CanceledError)

        raise
      end

      { 'cancelled' => false, 'result' => 'unexpected' }
    end
  end

  def test_nexus_operation_cancellation_try_cancel
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      execute_workflow(
        NexusCancellationWorkflow,
        endpoint,
        Temporalio::Workflow::NexusOperationCancellationType::TRY_CANCEL
      ) do |handle|
        assert_eventually { assert handle.query(NexusCancellationWorkflow.started) }
        assert_eventually { assert handle.query(NexusCancellationWorkflow.cancelled) }

        result = handle.result
        assert result['cancelled'] # steep:ignore
      end
    end
  end

  def test_nexus_operation_cancellation_abandon
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      execute_workflow(
        NexusCancellationWorkflow,
        endpoint,
        Temporalio::Workflow::NexusOperationCancellationType::ABANDON
      ) do |handle|
        assert_eventually { assert handle.query(NexusCancellationWorkflow.started) }
        assert_eventually { assert handle.query(NexusCancellationWorkflow.cancelled) }

        result = handle.result
        assert result['cancelled'] # steep:ignore
      end
    end
  end

  # Test multiple operations in sequence
  class NexusMultipleOperationsWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')

      # Execute sync operation
      sync_result = client.execute_operation('echo', 'success')

      # Execute async operation
      async_result = client.execute_operation('workflow-operation', { 'action' => 'success' })

      {
        'sync' => sync_result,
        'async' => async_result['result'] # steep:ignore
      }
    end
  end

  def test_nexus_multiple_operations_in_sequence
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      result = execute_workflow(NexusMultipleOperationsWorkflow, endpoint)

      assert_equal 'success', result['sync']
      assert_equal 'success', result['async']
    end
  end

  # Test concurrent operations
  class NexusConcurrentOperationsWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')

      # Start multiple operations concurrently
      handles = 3.times.map do |i|
        client.start_operation('echo', "op-#{i}")
      end

      # Wait for all to complete
      handles.map(&:result)
    end
  end

  def test_nexus_concurrent_operations
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      results = execute_workflow(NexusConcurrentOperationsWorkflow, endpoint)

      assert_equal 3, results.length
      assert_equal 'op-0', results[0]
      assert_equal 'op-1', results[1]
      assert_equal 'op-2', results[2]
    end
  end

  # Test operation with schedule_to_close_timeout (success case)
  class NexusOperationWithTimeoutSuccessWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      client.execute_operation('echo', 'success', schedule_to_close_timeout: 60)
    end
  end

  def test_nexus_operation_with_timeout
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      result = execute_workflow(NexusOperationWithTimeoutSuccessWorkflow, endpoint)

      assert_equal 'success', result
    end
  end

  # Test that Nexus operations can timeout
  class NexusOperationTimeoutWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      client.execute_operation(
        'workflow-operation',
        { 'action' => 'wait-for-cancel' },
        schedule_to_close_timeout: 0.1
      )
    end
  end

  def test_nexus_operation_timeout
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        execute_workflow(NexusOperationTimeoutWorkflow, endpoint)
      end

      # Should be a NexusOperationError wrapping a TimeoutError
      assert_instance_of Temporalio::Error::NexusOperationError, err.cause
      assert_instance_of Temporalio::Error::TimeoutError, err.cause.cause
      assert_includes err.cause.message, 'nexus operation completed unsuccessfully'
    end
  end

  # Test that NexusOperationError has correct attributes
  class NexusOperationErrorCheckWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      begin
        client.execute_operation('echo', 'fail')
      rescue Temporalio::Error::NexusOperationError => e
        {
          'endpoint' => e.endpoint,
          'service' => e.service,
          'operation' => e.operation,
          'has_token' => !e.operation_token.nil?,
          'message' => e.message
        }
      end
    end
  end

  def test_nexus_operation_error_attributes
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      result = execute_workflow(NexusOperationErrorCheckWorkflow, endpoint)

      assert_equal endpoint, result['endpoint']
      assert_equal 'test-service', result['service']
      assert_equal 'echo', result['operation']
      assert_equal false, result['has_token'] # Sync operation that fails immediately has no token
      assert_includes result['message'], 'nexus operation completed unsuccessfully'
    end
  end

  # Test using symbols for endpoint and service names
  class NexusSymbolNamesWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint: endpoint.to_sym, service: :'test-service')
      client.execute_operation(:echo, 'success')
    end
  end

  def test_nexus_operation_with_symbol_names
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      result = execute_workflow(NexusSymbolNamesWorkflow, endpoint)

      assert_equal 'success', result
    end
  end

  # Test handler error returned from Go side
  class NexusHandlerErrorWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      begin
        client.execute_operation('echo', 'fail')
      rescue Temporalio::Error::NexusOperationError => e
        # The handler error should be wrapped in the cause
        raise unless e.cause.is_a?(Temporalio::Error::NexusHandlerError)

        # steep:ignore:start
        {
          handler_error: true,
          error_type: e.cause.error_type,
          retry_behavior: e.cause.retry_behavior,
          message: e.cause.message
        }
        # steep:ignore:end
      end
    end
  end

  def test_nexus_handler_error
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      result = execute_workflow(NexusHandlerErrorWorkflow, endpoint)

      assert result['handler_error']
      assert_equal 'BAD_REQUEST', result['error_type']
      assert_equal Temporalio::Error::NexusHandlerError::RetryBehavior::UNSPECIFIED, result['retry_behavior']
      assert_includes result['message'], 'operation failed'
    end
  end

  # Test that summary appears in workflow history
  class NexusOperationSummaryWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      client.execute_operation('echo', 'success', summary: 'custom operation summary')
    end
  end

  def test_nexus_operation_summary_in_history
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      execute_workflow(NexusOperationSummaryWorkflow, endpoint) do |handle|
        assert_equal 'success', handle.result

        history_events = handle.fetch_history_events.to_a
        scheduled_event = history_events.find(&:nexus_operation_scheduled_event_attributes)
        summary_payload = scheduled_event.user_metadata.summary
        actual_summary = env.client.data_converter.from_payload(summary_payload)
        assert_equal 'custom operation summary', actual_summary
      end
    end
  end

  class NexusOperationTracingWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      client.execute_operation('echo', 'success')
    end
  end

  def test_nexus_operation_open_telemetry_tracing
    # Set up in-memory span exporter
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    tracer_provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    tracer_provider.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter))
    tracer = tracer_provider.tracer('nexus-test-tracer')
    tracing_interceptor = Temporalio::Contrib::OpenTelemetry::TracingInterceptor.new(tracer)

    # Create client with tracing interceptor
    new_options = env.client.options.with(interceptors: [tracing_interceptor])
    traced_client = Temporalio::Client.new(**new_options.to_h) # steep:ignore

    env.with_kitchen_sink_worker(traced_client, nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"

      # Execute workflow
      result = execute_workflow(
        NexusOperationTracingWorkflow,
        endpoint,
        client: traced_client
      )
      assert_equal 'success', result

      # Verify StartNexusOperation span was created with correct name
      finished_spans = exporter.finished_spans
      span_names = finished_spans.map(&:name)
      assert_includes span_names, 'StartNexusOperation:test-service/echo',
                      "Expected StartNexusOperation span, got: #{span_names.inspect}"
    end
  end
end
