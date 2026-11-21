# frozen_string_literal: true

require 'base64_codec'
require 'in_memory_storage_driver'
require 'securerandom'
require 'temporalio/client'
require 'temporalio/converters/external_storage'
require 'temporalio/converters/storage_driver_activity_info'
require 'temporalio/converters/storage_driver_workflow_info'
require 'temporalio/error'
require 'temporalio/internal/external_storage_references'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

class WorkerExternalStorageTest < Test
  References = Temporalio::Internal::ExternalStorageReferences
  WorkflowTarget = Temporalio::Converters::StorageDriverWorkflowInfo
  ActivityTarget = Temporalio::Converters::StorageDriverActivityInfo

  class StorageActivity < Temporalio::Activity::Definition
    def execute(input)
      "activity got #{input}"
    end
  end

  class StorageWorkflow < Temporalio::Workflow::Definition
    def execute(input)
      activity_result = Temporalio::Workflow.execute_activity(StorageActivity, input, start_to_close_timeout: 10)
      Temporalio::Workflow.wait_condition { @signal_input }
      "#{activity_result} #{@signal_input}"
    end

    workflow_signal
    def finish(input)
      @signal_input = input
    end

    workflow_query
    def echo_query(input)
      "query got #{input}"
    end

    workflow_update
    def echo_update(input)
      "update got #{input}"
    end
  end

  def test_workflow_payloads_are_stored_as_references_in_history
    client = client_with_storage(InMemoryStorageDriver.new)
    execute_workflow(
      StorageWorkflow, 'start-input',
      activities: [StorageActivity],
      memo: { 'memo-key' => 'memo-value' },
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'query got query-input', handle.query(StorageWorkflow.echo_query, 'query-input')
      assert_equal 'update got update-input', handle.execute_update(StorageWorkflow.echo_update, 'update-input')
      handle.signal(StorageWorkflow.finish, 'signal-input')
      assert_equal 'activity got start-input signal-input', handle.result
      assert_equal 'memo-value', handle.describe.memo['memo-key']

      events = handle.fetch_history_events
      attrs = first_attrs(events, :workflow_execution_started_event_attributes)
      assert_reference attrs.input.payloads.first
      assert_reference attrs.memo.fields['memo-key']
      assert_reference first_attrs(events, :activity_task_scheduled_event_attributes).input.payloads.first
      assert_reference first_attrs(events, :activity_task_completed_event_attributes).result.payloads.first
      assert_reference first_attrs(events, :workflow_execution_signaled_event_attributes).input.payloads.first
      assert_reference first_attrs(events, :workflow_execution_update_accepted_event_attributes)
        .accepted_request.input.args.payloads.first
      assert_reference first_attrs(events, :workflow_execution_update_completed_event_attributes)
        .outcome.success.payloads.first
      assert_reference first_attrs(events, :workflow_execution_completed_event_attributes).result.payloads.first
    end
  end

  def test_client_without_storage_cannot_read_stored_result
    execute_workflow(
      StorageWorkflow, 'start-input',
      activities: [StorageActivity],
      client: client_with_storage(InMemoryStorageDriver.new),
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      handle.signal(StorageWorkflow.finish, 'signal-input')
      handle.result

      assert_raises(Temporalio::Error::ExternalStorageNotConfiguredError) do
        env.client.workflow_handle(handle.id).result
      end
    end
  end

  def test_codec_encodes_payloads_before_they_are_stored
    driver = InMemoryStorageDriver.new
    client = client_with_storage(driver, payload_codec: Base64Codec.new)
    execute_workflow(
      StorageWorkflow, 'start-input',
      activities: [StorageActivity],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      handle.signal(StorageWorkflow.finish, 'signal-input')
      assert_equal 'activity got start-input signal-input', handle.result

      # The reference itself is not encoded, but the payload it points at is
      reference = first_attrs(handle.fetch_history_events, :workflow_execution_started_event_attributes)
                  .input.payloads.first
      assert_reference reference
      stored = Temporalio::Api::Common::V1::Payload.decode(
        driver.stored.fetch(References.parse_reference(reference).claim_data['key'])
      )
      assert_equal 'test/base64', stored.metadata['encoding']
    end
  end

  class HeartbeatRetryActivity < Temporalio::Activity::Definition
    # Raw args take a separate decoding path from converted args
    activity_raw_args

    def execute(*raw_args)
      context = Temporalio::Activity::Context.current
      if context.info.attempt == 1
        context.heartbeat('heartbeat-detail')
        raise 'Intentional error'
      end
      input = context.payload_converter.from_payload(raw_args.first.payload)
      "#{input} #{context.info.heartbeat_details.first}"
    end
  end

  class HeartbeatRetryWorkflow < Temporalio::Workflow::Definition
    def execute(input)
      Temporalio::Workflow.execute_activity(
        HeartbeatRetryActivity, input,
        start_to_close_timeout: 10,
        heartbeat_timeout: 5,
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: 2, initial_interval: 0.1)
      )
    end
  end

  def test_activity_reads_stored_raw_args_and_heartbeat_details
    client = client_with_storage(InMemoryStorageDriver.new)
    assert_equal 'activity-input heartbeat-detail', execute_workflow(
      HeartbeatRetryWorkflow, 'activity-input',
      activities: [HeartbeatRetryActivity],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    )
  end

  # Fails once: either the first retrieve, or the first store of a payload containing the given text
  class FailOnceStorageDriver < InMemoryStorageDriver
    def initialize(fail_retrieve: false, fail_store_containing: nil)
      super()
      @fail_retrieve = fail_retrieve
      @fail_store_containing = fail_store_containing
    end

    def store(context, payloads)
      text = @fail_store_containing
      if text && payloads.any? { |payload| payload.data.include?(text) }
        @fail_store_containing = nil
        raise 'Intentional store failure'
      end
      super
    end

    def retrieve(context, claims)
      if @fail_retrieve
        @fail_retrieve = false
        raise 'Intentional retrieve failure'
      end
      super
    end
  end

  class EchoWorkflow < Temporalio::Workflow::Definition
    def execute(input)
      "#{input} done"
    end
  end

  class NoInputWorkflow < Temporalio::Workflow::Definition
    def execute
      'no-input result'
    end
  end

  def test_workflow_worker_stores_carry_the_worker_namespace
    driver = InMemoryStorageDriver.new
    client = client_with_storage(driver)
    execute_workflow(
      NoInputWorkflow, client:, workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'no-input result', handle.result
    end

    # With no input, every store here is the workflow worker's, not the client's.
    refute_empty driver.store_calls
    assert_equal [client.namespace], driver.store_calls.map { |context, _size| context.namespace }.uniq
  end

  def test_worker_retrieve_failure_fails_the_task_and_is_retried
    assert_storage_failure_retried(
      FailOnceStorageDriver.new(fail_retrieve: true),
      "External storage driver 'mem' failed to retrieve payloads: Intentional retrieve failure"
    )
  end

  def test_worker_store_failure_fails_the_task_and_is_retried
    assert_storage_failure_retried(
      FailOnceStorageDriver.new(fail_store_containing: 'done'),
      "Failed encoding completion: External storage driver 'mem' failed to store payloads: Intentional store failure"
    )
  end

  def test_worker_without_storage_fails_the_task_on_a_reference
    execute_workflow(
      EchoWorkflow, 'start-input',
      start_workflow_client: client_with_storage(InMemoryStorageDriver.new)
    ) do |handle|
      assert_eventually do
        failure = handle.fetch_history_events.filter_map(&:workflow_task_failed_event_attributes).first
        refute_nil failure
        assert_includes failure.failure.message, 'TMPRL1105'
        assert_equal :WORKFLOW_TASK_FAILED_CAUSE_EXTERNAL_STORAGE_FAILURE, failure.cause
      end
    end
  end

  class AsyncCompletionActivity < Temporalio::Activity::Definition
    def initialize
      @task_token = Queue.new
    end

    def execute
      @task_token.push(Temporalio::Activity::Context.current.info.task_token)
      raise Temporalio::Activity::CompleteAsyncError
    end

    def wait_task_token
      @task_token.pop
    end
  end

  class AsyncCompletionWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.execute_activity(AsyncCompletionActivity, start_to_close_timeout: 10)
    end
  end

  def test_async_activity_completion_is_stored
    client = client_with_storage(InMemoryStorageDriver.new)
    activity = AsyncCompletionActivity.new
    execute_workflow(
      AsyncCompletionWorkflow,
      activities: [activity],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      client.async_activity_handle(activity.wait_task_token).complete('async-result')

      assert_equal 'async-result', handle.result
      assert_reference first_attrs(handle.fetch_history_events, :activity_task_completed_event_attributes)
        .result.payloads.first
    end
  end

  def test_schedule_arguments_are_stored
    client = client_with_storage(InMemoryStorageDriver.new)
    handle = client.create_schedule(
      "sched-#{SecureRandom.uuid}",
      Temporalio::Client::Schedule.new(
        action: Temporalio::Client::Schedule::Action::StartWorkflow.new(
          EchoWorkflow, 'schedule-input', id: "wf-#{SecureRandom.uuid}", task_queue: "tq-#{SecureRandom.uuid}"
        ),
        spec: Temporalio::Client::Schedule::Spec.new,
        state: Temporalio::Client::Schedule::State.new(paused: true)
      )
    )
    begin
      description = handle.describe
      action = description.schedule.action #: Temporalio::Client::Schedule::Action::StartWorkflow
      assert_equal ['schedule-input'], action.args
      assert_reference description.raw_description.schedule.action.start_workflow.input.payloads.first
    ensure
      handle.delete
    end
  end

  def test_driver_store_failure_surfaces_to_the_client
    client = client_with_storage(FailOnceStorageDriver.new(fail_store_containing: 'start-input'))

    error = assert_raises(Temporalio::Error::ExternalStorageError) do
      client.start_workflow(EchoWorkflow, 'start-input', id: "wf-#{SecureRandom.uuid}", task_queue: 'unused')
    end
    assert_equal 'Intentional store failure', error.cause&.message
  end

  class ChildWorkflow < Temporalio::Workflow::Definition
    def execute(input)
      "child got #{input}"
    end
  end

  class ParentWorkflow < Temporalio::Workflow::Definition
    def execute(input)
      Temporalio::Workflow.execute_child_workflow(ChildWorkflow, input)
    end
  end

  def test_child_workflow_input_and_result_are_stored
    execute_workflow(
      ParentWorkflow, 'child-input',
      more_workflows: [ChildWorkflow],
      client: client_with_storage(InMemoryStorageDriver.new),
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'child got child-input', handle.result

      events = handle.fetch_history_events
      assert_reference first_attrs(events, :start_child_workflow_execution_initiated_event_attributes)
        .input.payloads.first
      assert_reference first_attrs(events, :child_workflow_execution_completed_event_attributes)
        .result.payloads.first
    end
  end

  class LocalActivityWorkflow < Temporalio::Workflow::Definition
    def execute(input)
      Temporalio::Workflow.execute_local_activity(StorageActivity, input, start_to_close_timeout: 10)
    end
  end

  def test_local_activity_result_is_stored
    execute_workflow(
      LocalActivityWorkflow, 'local-input',
      activities: [StorageActivity],
      client: client_with_storage(InMemoryStorageDriver.new),
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'activity got local-input', handle.result

      # Core records a local activity's result in the marker's details
      marker = first_attrs(handle.fetch_history_events, :marker_recorded_event_attributes)
      assert_reference marker.details['result'].payloads.first
    end
  end

  class FailingActivity < Temporalio::Activity::Definition
    def execute
      raise Temporalio::Error::ApplicationError.new('Activity failed', 'activity-detail', non_retryable: true)
    end
  end

  class ActivityFailureWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.execute_activity(FailingActivity, start_to_close_timeout: 10)
    rescue Temporalio::Error::ActivityError => e
      cause = e.cause #: Temporalio::Error::ApplicationError
      cause.details.first
    end
  end

  def test_activity_failure_details_are_stored
    execute_workflow(
      ActivityFailureWorkflow,
      activities: [FailingActivity],
      client: client_with_storage(InMemoryStorageDriver.new),
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'activity-detail', handle.result

      failure = first_attrs(handle.fetch_history_events, :activity_task_failed_event_attributes).failure
      assert_equal 'Activity failed', failure.message
      assert_reference failure.application_failure_info.details.payloads.first
    end
  end

  def test_activity_result_store_failure_fails_with_storage_cause_and_is_retried
    driver = FailOnceStorageDriver.new(fail_store_containing: 'activity got')
    result, completions = execute_workflow_capturing_activity_completions(
      ScheduleActivityWorkflow, activities: [StorageActivity], driver:
    )

    assert_equal 'activity got scheduled-input', result
    failed_result = first_failed_result(completions)
    assert_equal :ACTIVITY_TASK_FAILED_CAUSE_EXTERNAL_STORAGE_FAILURE, failed_result.cause
    assert_equal "External storage driver 'mem' failed to store payloads: Intentional store failure",
                 failed_result.failure.message
  end

  def test_activity_failure_store_failure_is_reported_without_storing
    driver = FailOnceStorageDriver.new(fail_store_containing: 'activity-detail')
    result, completions = execute_workflow_capturing_activity_completions(
      ActivityFailureWorkflow, activities: [FailingActivity], driver:
    )

    assert_equal 'activity-detail', result
    failed_result = first_failed_result(completions)
    assert_equal :ACTIVITY_TASK_FAILED_CAUSE_EXTERNAL_STORAGE_FAILURE, failed_result.cause
    activity_failure = failed_result.failure.cause&.cause or flunk('No activity failure in the cause chain')
    assert_equal 'Activity failed', activity_failure.message
    refute References.reference?(activity_failure.application_failure_info.details.payloads.first)
  end

  class HeartbeatStoreFailureActivity < Temporalio::Activity::Definition
    def execute
      Temporalio::Activity::Context.current.heartbeat('failing-heartbeat')
      sleep(1)
      raise 'Activity was not canceled'
    end
  end

  class HeartbeatStoreFailureWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.execute_activity(
        HeartbeatStoreFailureActivity,
        start_to_close_timeout: 5, retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
      )
    rescue Temporalio::Error::ActivityError => e
      e.cause&.message
    end
  end

  def test_heartbeat_store_failure_cancels_the_activity_and_fails_it_with_storage_cause
    driver = FailOnceStorageDriver.new(fail_store_containing: 'failing-heartbeat')
    result, completions = execute_workflow_capturing_activity_completions(
      HeartbeatStoreFailureWorkflow, activities: [HeartbeatStoreFailureActivity], driver:
    )

    message = "External storage driver 'mem' failed to store payloads: Intentional store failure"
    assert_equal message, result
    failed_result = first_failed_result(completions)
    assert_equal :ACTIVITY_TASK_FAILED_CAUSE_EXTERNAL_STORAGE_FAILURE, failed_result.cause
    assert_equal message, failed_result.failure.message
  end

  def test_activity_input_retrieve_failure_fails_with_storage_cause_and_is_retried
    driver = FailOnceStorageDriver.new(fail_retrieve: true)
    result, completions = execute_workflow_capturing_activity_completions(
      ScheduleActivityWorkflow, activities: [StorageActivity], driver:
    )

    assert_equal 'activity got scheduled-input', result
    failed_result = first_failed_result(completions)
    assert_equal :ACTIVITY_TASK_FAILED_CAUSE_EXTERNAL_STORAGE_FAILURE, failed_result.cause
    assert_equal "External storage driver 'mem' failed to retrieve payloads: Intentional retrieve failure",
                 failed_result.failure.message
  end

  class UnconvertibleDetail
    def to_json(*)
      raise 'Intentional conversion failure'
    end
  end

  class HeartbeatConversionFailureActivity < Temporalio::Activity::Definition
    def execute
      Temporalio::Activity::Context.current.heartbeat(UnconvertibleDetail.new)
      sleep(1)
      raise 'Activity was not canceled'
    end
  end

  def test_heartbeat_conversion_failure_cancels_the_activity_and_fails_it_without_storage_cause
    result, completions = execute_workflow_capturing_activity_completions(
      CancelOnSignalWorkflow, 'HeartbeatConversionFailureActivity',
      activities: [HeartbeatConversionFailureActivity], driver: InMemoryStorageDriver.new
    )

    assert_equal 'Intentional conversion failure', result
    failed_result = first_failed_result(completions)
    assert_equal :ACTIVITY_TASK_FAILED_CAUSE_UNSPECIFIED, failed_result.cause
    assert_equal 'Intentional conversion failure', failed_result.failure.message
  end

  class HeartbeatStoreFailureNoRaiseActivity < Temporalio::Activity::Definition
    activity_cancel_raise false

    def execute
      Temporalio::Activity::Context.current.heartbeat('failing-heartbeat')
      Temporalio::Activity::Context.current.cancellation.check!
      raise 'Activity was not canceled'
    end
  end

  def test_heartbeat_store_failure_is_seen_by_an_activity_that_does_not_raise_on_cancel
    driver = FailOnceStorageDriver.new(fail_store_containing: 'failing-heartbeat')
    result, completions = execute_workflow_capturing_activity_completions(
      CancelOnSignalWorkflow, 'HeartbeatStoreFailureNoRaiseActivity',
      activities: [HeartbeatStoreFailureNoRaiseActivity], driver:
    )

    message = "External storage driver 'mem' failed to store payloads: Intentional store failure"
    assert_equal message, result
    failed_result = first_failed_result(completions)
    assert_equal :ACTIVITY_TASK_FAILED_CAUSE_EXTERNAL_STORAGE_FAILURE, failed_result.cause
    assert_equal message, failed_result.failure.message
  end

  class CancelOnSignalWorkflow < Temporalio::Workflow::Definition
    def execute(activity)
      cancellation, cancel_proc = Temporalio::Cancellation.new
      Temporalio::Workflow::Future.new do
        Temporalio::Workflow.wait_condition { @cancel }
        cancel_proc.call
      end
      Temporalio::Workflow.execute_activity(
        activity,
        start_to_close_timeout: 10, heartbeat_timeout: 1, cancellation:,
        cancellation_type: Temporalio::Workflow::ActivityCancellationType::WAIT_CANCELLATION_COMPLETED,
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
      )
    rescue Temporalio::Error::ActivityError => e
      e.cause.is_a?(Temporalio::Error::CanceledError) ? 'canceled' : e.cause&.message
    end

    workflow_signal
    def cancel
      @cancel = true
    end
  end

  class BlockOnceStorageDriver < InMemoryStorageDriver
    attr_reader :blocked

    def initialize(block_store_containing:)
      super()
      @block_store_containing = block_store_containing
      @blocked = Queue.new
    end

    def store(context, payloads)
      block_text = @block_store_containing
      if block_text && payloads.any? { |payload| payload.data.include?(block_text) }
        @block_store_containing = nil
        @blocked << true
        sleep(5)
      end
      super
    end
  end

  class HeartbeatStoreBlockedActivity < Temporalio::Activity::Definition
    def execute
      context = Temporalio::Activity::Context.current
      heartbeater = Thread.new do
        loop do
          context.heartbeat('background-heartbeat')
          sleep(0.1)
        end
      end
      begin
        context.heartbeat('blocked-heartbeat')
        raise 'Activity was not canceled'
      ensure
        heartbeater.kill
      end
    end
  end

  def test_cancel_while_storing_a_heartbeat_is_reported_as_canceled
    driver = BlockOnceStorageDriver.new(block_store_containing: 'blocked-heartbeat')
    result, completions = execute_workflow_capturing_activity_completions(
      CancelOnSignalWorkflow, 'HeartbeatStoreBlockedActivity',
      activities: [HeartbeatStoreBlockedActivity], driver:
    ) do |handle|
      driver.blocked.pop(timeout: 10) or flunk('Heartbeat store never started')
      handle.signal(CancelOnSignalWorkflow.cancel)
    end

    assert_equal 'canceled', result
    refute completions.any? { |completion| completion.result.failed }, 'Expected no failed completion'
    canceled_result = first_canceled_result(completions)
    assert_equal 'Activity canceled', canceled_result.failure.message
  end

  class HeartbeatFailureThenServerCancelActivity < Temporalio::Activity::Definition
    activity_cancel_raise false

    def execute
      context = Temporalio::Activity::Context.current
      context.heartbeat('failing-heartbeat')
      raise 'Heartbeat failure did not cancel' unless context.cancellation.canceled?

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      until context.cancellation_details
        raise 'Server cancel never arrived' if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        context.heartbeat('ok-heartbeat')
        sleep(0.1)
      end
      raise Temporalio::Error::CanceledError, 'Canceled by server'
    end
  end

  class ReportingFailOnceStorageDriver < FailOnceStorageDriver
    attr_reader :failures

    def initialize(...)
      super
      @failures = Queue.new
    end

    def store(context, payloads)
      super
    rescue StandardError => e
      @failures << e
      raise
    end
  end

  def test_server_cancel_after_heartbeat_failure_is_reported_as_canceled
    driver = ReportingFailOnceStorageDriver.new(fail_store_containing: 'failing-heartbeat')
    result, completions = execute_workflow_capturing_activity_completions(
      CancelOnSignalWorkflow, 'HeartbeatFailureThenServerCancelActivity',
      activities: [HeartbeatFailureThenServerCancelActivity], driver:
    ) do |handle|
      driver.failures.pop(timeout: 10) or flunk('Heartbeat store never failed')
      handle.signal(CancelOnSignalWorkflow.cancel)
    end

    assert_equal 'canceled', result
    refute completions.any? { |completion| completion.result.failed }, 'Expected no failed completion'
    canceled_result = first_canceled_result(completions)
    assert_equal 'Canceled by server', canceled_result.failure.message
  end

  class FailingWorkflow < Temporalio::Workflow::Definition
    def execute
      raise Temporalio::Error::ApplicationError.new('Workflow failed', 'workflow-detail')
    end
  end

  def test_workflow_failure_details_are_stored
    execute_workflow(
      FailingWorkflow,
      client: client_with_storage(InMemoryStorageDriver.new),
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      error = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_equal ['workflow-detail'], error.cause.details

      failure = first_attrs(handle.fetch_history_events, :workflow_execution_failed_event_attributes).failure
      assert_reference failure.application_failure_info.details.payloads.first
    end
  end

  class NexusWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      client.execute_operation('echo', 'nexus-input')
    end
  end

  exclude_from_cloud :needs_cloud_adaptation,
                     'Requires Cloud Nexus endpoint setup and a Go worker with Cloud TLS configuration.'
  def test_nexus_operation_input_is_stored
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      execute_workflow(
        NexusWorkflow, "nexus-endpoint-#{task_queue}",
        client: client_with_storage(InMemoryStorageDriver.new),
        workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
      ) do |handle|
        # The Go handler worker has no storage, so it rejects the reference it receives and the operation fails
        error = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
        assert_instance_of Temporalio::Error::NexusOperationError, error.cause

        scheduled = first_attrs(handle.fetch_history_events, :nexus_operation_scheduled_event_attributes)
        assert_reference scheduled.input
      end
    end
  end

  class HandlerWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_signal
    def notify(input); end

    workflow_update
    def change(input)
      input
    end
  end

  def test_worker_without_storage_fails_the_task_on_a_signal_reference
    execute_workflow(HandlerWorkflow) do |handle|
      client_with_storage(InMemoryStorageDriver.new).workflow_handle(handle.id)
                                                    .signal(HandlerWorkflow.notify, 'signal-input')

      assert_eventually_task_fail(handle:, message_contains: 'TMPRL1105')
    end
  end

  def test_worker_without_storage_fails_the_task_on_an_update_reference
    execute_workflow(HandlerWorkflow) do |handle|
      storage_handle = client_with_storage(InMemoryStorageDriver.new).workflow_handle(handle.id)
      # The update is never accepted, so wait for it in the background until the workflow is terminated
      run_in_background do
        storage_handle.execute_update(HandlerWorkflow.change, 'update-input')
      rescue Temporalio::Error
        nil
      end

      assert_eventually_task_fail(handle:, message_contains: 'TMPRL1105')
      handle.terminate
    end
  end

  def test_workflow_task_completions_report_storage_metrics
    driver = InMemoryStorageDriver.new
    completions = run_echo_workflow_capturing_completions(driver)

    # The first task retrieves the input and stores the result
    first = completions.first or flunk('No completions')
    stored_sizes = driver.stored.values.map(&:bytesize).sort
    download = first.payload_download_metrics or flunk('No download metrics')
    upload = first.payload_upload_metrics or flunk('No upload metrics')
    assert_equal 1, download.payload_count
    assert_equal 1, upload.payload_count
    assert_equal stored_sizes, [download.total_size_bytes, upload.total_size_bytes].sort
    assert_equal ['mem'], download.driver_names.to_a
    assert_equal ['mem'], upload.driver_names.to_a
  end

  def test_failed_store_still_reports_download_metrics
    completions = run_echo_workflow_capturing_completions(FailOnceStorageDriver.new(fail_store_containing: 'done'))

    failed = completions.find(&:failed) or flunk('No failed completion')
    download = failed.payload_download_metrics or flunk('No download metrics')
    assert_equal 1, download.payload_count
    assert_equal ['mem'], download.driver_names.to_a
    assert_nil failed.payload_upload_metrics
  end

  def test_workflow_result_is_stored_for_the_workflow
    driver = InMemoryStorageDriver.new
    execute_workflow(
      EchoWorkflow, 'start-input',
      client: client_with_storage(driver),
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'start-input done', handle.result
      assert_equal [workflow_target(handle)], targets_of(driver, 'start-input done')
      assert_equal [env.client.namespace], driver.namespaces_of_payloads_with_data('start-input done'.to_json)
    end
  end

  class ScheduleActivityWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.execute_activity(StorageActivity, 'scheduled-input', start_to_close_timeout: 10)
    end
  end

  def test_workflow_activity_payloads_are_stored_for_the_workflow
    driver = InMemoryStorageDriver.new
    execute_workflow(
      ScheduleActivityWorkflow,
      activities: [StorageActivity],
      client: client_with_storage(driver),
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'activity got scheduled-input', handle.result
      workflow = workflow_target(handle)
      assert_equal [workflow], targets_of(driver, 'scheduled-input')
      stored_as_activity_result_then_workflow_result = [workflow, workflow]
      assert_equal stored_as_activity_result_then_workflow_result, targets_of(driver, 'activity got scheduled-input')
    end
  end

  def test_heartbeat_details_are_stored_for_the_workflow
    driver = InMemoryStorageDriver.new
    execute_workflow(
      HeartbeatRetryWorkflow, 'activity-input',
      activities: [HeartbeatRetryActivity],
      client: client_with_storage(driver),
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'activity-input heartbeat-detail', handle.result
      assert_equal [workflow_target(handle)], targets_of(driver, 'heartbeat-detail')
    end
  end

  def test_standalone_activity_result_is_stored_for_the_activity
    driver = InMemoryStorageDriver.new
    client = client_with_storage(driver)
    worker = Temporalio::Worker.new(client:, task_queue: "tq-#{SecureRandom.uuid}", activities: [StorageActivity])
    worker.run do
      handle = client.start_activity(
        StorageActivity, 'standalone-input',
        id: "act-#{SecureRandom.uuid}", task_queue: worker.task_queue, start_to_close_timeout: 10
      )
      assert_equal 'activity got standalone-input', handle.result
      expected = ActivityTarget.new(
        namespace: client.namespace, id: handle.id, run_id: handle.run_id,
        type: Temporalio::Activity::Definition::Info.from_activity(StorageActivity).name.to_s
      )
      assert_equal [expected], targets_of(driver, 'activity got standalone-input')
      assert_equal [client.namespace], driver.namespaces_of_payloads_with_data('activity got standalone-input'.to_json)
    end
  end

  class TargetParentWorkflow < Temporalio::Workflow::Definition
    def execute
      child_result = Temporalio::Workflow.execute_child_workflow(
        ChildWorkflow, 'to-child', id: "#{Temporalio::Workflow.info.workflow_id}-child"
      )
      "parent got #{child_result}"
    end
  end

  def test_child_input_is_stored_for_the_child_and_its_result_for_the_parent
    driver = InMemoryStorageDriver.new
    client = client_with_storage(driver)
    execute_workflow(
      TargetParentWorkflow,
      more_workflows: [ChildWorkflow],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'parent got child got to-child', handle.result

      child = WorkflowTarget.new(
        namespace: client.namespace, id: "#{handle.id}-child",
        type: Temporalio::Workflow::Definition::Info.from_class(ChildWorkflow).name
      )
      assert_equal [child], targets_of(driver, 'to-child')
      parent = WorkflowTarget.new(namespace: client.namespace, id: handle.id, run_id: handle.result_run_id)
      assert_equal [parent], targets_of(driver, 'child got to-child')
    end
  end

  class SignalExternalWorkflow < Temporalio::Workflow::Definition
    def execute(workflow_id, run_id)
      Temporalio::Workflow.external_workflow_handle(workflow_id, run_id:)
                          .signal(HandlerWorkflow.notify, 'external-signal')
    end
  end

  def test_external_signal_is_stored_for_the_signaled_workflow
    driver = InMemoryStorageDriver.new
    client = client_with_storage(driver)
    execute_workflow(
      HandlerWorkflow,
      more_workflows: [SignalExternalWorkflow],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle, worker|
      client.execute_workflow(
        SignalExternalWorkflow, handle.id, handle.result_run_id,
        id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue
      )

      expected = WorkflowTarget.new(namespace: client.namespace, id: handle.id, run_id: handle.result_run_id)
      assert_equal [expected], targets_of(driver, 'external-signal')
      handle.terminate
    end
  end

  class ContinueAsNewWorkflow < Temporalio::Workflow::Definition
    def execute(stage)
      case stage
      when 'start' then raise Temporalio::Workflow::ContinueAsNewError, 'same-type'
      when 'same-type' then raise Temporalio::Workflow::ContinueAsNewError.new('new-type', workflow: EchoWorkflow)
      else raise "Unexpected stage #{stage}"
      end
    end
  end

  def test_continue_as_new_input_is_stored_for_the_next_run
    driver = InMemoryStorageDriver.new
    client = client_with_storage(driver)
    execute_workflow(
      ContinueAsNewWorkflow, 'start',
      more_workflows: [EchoWorkflow],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'new-type done', handle.result

      next_run_same_type = WorkflowTarget.new(
        namespace: client.namespace, id: handle.id,
        type: Temporalio::Workflow::Definition::Info.from_class(ContinueAsNewWorkflow).name
      )
      assert_equal [next_run_same_type], targets_of(driver, 'same-type')
      next_run_new_type = WorkflowTarget.new(
        namespace: client.namespace, id: handle.id,
        type: Temporalio::Workflow::Definition::Info.from_class(EchoWorkflow).name
      )
      assert_equal [next_run_new_type], targets_of(driver, 'new-type')
    end
  end

  def test_failure_of_a_run_with_no_instance_is_stored_for_the_workflow
    driver = InMemoryStorageDriver.new
    client = client_storing_failure_messages(driver)
    worker = Temporalio::Worker.new(
      client:, task_queue: "tq-#{SecureRandom.uuid}", workflows: [EchoWorkflow],
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    )
    worker.run do
      handle = client.start_workflow(
        'UnregisteredWorkflow', id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue
      )
      assert_eventually_task_fail(handle:)

      expected = WorkflowTarget.new(
        namespace: client.namespace, id: handle.id, run_id: handle.result_run_id, type: 'UnregisteredWorkflow'
      )
      refute_empty driver.store_calls
      driver.store_calls.map(&:first).each do |context|
        assert_equal expected, context.target
        assert_equal client.namespace, context.namespace
      end
      handle.terminate
    end
  end

  def test_failure_of_an_activity_that_cannot_start_is_stored_for_the_activity
    driver = InMemoryStorageDriver.new
    client = client_storing_failure_messages(driver)
    worker = Temporalio::Worker.new(client:, task_queue: "tq-#{SecureRandom.uuid}", activities: [StorageActivity])
    worker.run do
      handle = client.start_activity(
        'UnregisteredActivity',
        id: "act-#{SecureRandom.uuid}", task_queue: worker.task_queue, start_to_close_timeout: 10,
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
      )
      assert_raises(Temporalio::Error::ActivityFailedError) { handle.result }

      expected = ActivityTarget.new(
        namespace: client.namespace, id: handle.id, run_id: handle.run_id, type: 'UnregisteredActivity'
      )
      refute_empty driver.store_calls
      driver.store_calls.map(&:first).each do |context|
        assert_equal expected, context.target
        assert_equal client.namespace, context.namespace
      end
    end
  end

  class SignalChildWorkflow < Temporalio::Workflow::Definition
    def execute
      child = Temporalio::Workflow.start_child_workflow(
        HandlerWorkflow, id: "#{Temporalio::Workflow.info.workflow_id}-child"
      )
      child.signal(HandlerWorkflow.notify, 'child-signal')
    end
  end

  def test_child_signal_is_stored_for_the_child
    driver = InMemoryStorageDriver.new
    client = client_with_storage(driver)
    execute_workflow(
      SignalChildWorkflow,
      more_workflows: [HandlerWorkflow],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      handle.result

      child_without_run_id = WorkflowTarget.new(namespace: client.namespace, id: "#{handle.id}-child")
      assert_equal [child_without_run_id], targets_of(driver, 'child-signal')
    end
  end

  class ContinuingChildWorkflow < Temporalio::Workflow::Definition
    def execute(stage)
      raise Temporalio::Workflow::ContinueAsNewError, 'continued-child' if stage == 'start'

      "child finished #{stage}"
    end
  end

  class ContinuingChildParentWorkflow < Temporalio::Workflow::Definition
    def execute
      child_result = Temporalio::Workflow.execute_child_workflow(
        ContinuingChildWorkflow, 'start', id: "#{Temporalio::Workflow.info.workflow_id}-child"
      )
      "parent got #{child_result}"
    end
  end

  def test_result_of_a_child_that_continued_as_new_is_stored_for_the_child
    driver = InMemoryStorageDriver.new
    client = client_with_storage(driver)
    execute_workflow(
      ContinuingChildParentWorkflow,
      more_workflows: [ContinuingChildWorkflow],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'parent got child finished continued-child', handle.result

      child_description = client.workflow_handle("#{handle.id}-child").describe
      continued_child_run = WorkflowTarget.new(
        namespace: client.namespace, id: child_description.id, run_id: child_description.run_id,
        type: child_description.workflow_type
      )
      assert_equal [continued_child_run], targets_of(driver, 'child finished continued-child')
    end
  end

  private

  def run_echo_workflow_capturing_completions(driver)
    client = client_with_storage(driver)
    worker = Temporalio::Worker.new(
      client:,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [EchoWorkflow],
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    )
    completions = Queue.new
    bridge_worker = worker._bridge_worker
    complete = bridge_worker.method(:async_complete_workflow_activation)
    bridge_worker.define_singleton_method(:async_complete_workflow_activation) do |run_id, proto, queue|
      completions << Temporalio::Internal::Bridge::Api::WorkflowCompletion::WorkflowActivationCompletion.decode(proto)
      complete.call(run_id, proto, queue)
    end
    worker.run do
      result = client.execute_workflow(
        EchoWorkflow, 'start-input', id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue
      )
      assert_equal 'start-input done', result
    end
    Array.new(completions.size) { completions.pop }
  end

  def execute_workflow_capturing_activity_completions(workflow, *args, activities:, driver:)
    client = client_with_storage(driver)
    worker = Temporalio::Worker.new(
      client:,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [workflow],
      activities:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    )
    completions = Queue.new
    bridge_worker = worker._bridge_worker
    original_complete_activity_task = bridge_worker.method(:async_complete_activity_task)
    bridge_worker.define_singleton_method(:async_complete_activity_task) do |proto, queue|
      completions << Temporalio::Internal::Bridge::Api::CoreInterface::ActivityTaskCompletion.decode(proto)
      original_complete_activity_task.call(proto, queue)
    end
    result = nil
    worker.run do
      handle = client.start_workflow(workflow, *args, id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue)
      yield handle if block_given?
      result = handle.result
    end
    [result, Array.new(completions.size) { completions.pop }]
  end

  def assert_storage_failure_retried(driver, failure_message)
    execute_workflow(
      EchoWorkflow, 'start-input',
      client: client_with_storage(driver),
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'start-input done', handle.result
      task_failed_attrs = first_attrs(handle.fetch_history_events, :workflow_task_failed_event_attributes)
      assert_equal failure_message, task_failed_attrs.failure.message
      assert_equal :WORKFLOW_TASK_FAILED_CAUSE_EXTERNAL_STORAGE_FAILURE, task_failed_attrs.cause
    end
  end

  def client_with_storage(driver, payload_codec: nil, failure_converter: Temporalio::Converters::FailureConverter.default)
    data_converter = Temporalio::Converters::DataConverter.new(
      failure_converter:,
      payload_codec:,
      external_storage: Temporalio::Converters::ExternalStorage.new(drivers: [driver], payload_size_threshold: 0)
    )
    Temporalio::Client.new(**env.client.options.with(data_converter:).to_h) # steep:ignore InsufficientKeywordArguments
  end

  def workflow_target(handle)
    WorkflowTarget.new(
      namespace: env.client.namespace, id: handle.id, run_id: handle.result_run_id,
      type: handle.describe.workflow_type
    )
  end

  def client_storing_failure_messages(driver)
    client_with_storage(
      driver, failure_converter: Temporalio::Converters::FailureConverter.new(encode_common_attributes: true)
    )
  end

  def targets_of(driver, value)
    driver.targets_of_payloads_with_data(value.to_json)
  end

  def first_failed_result(activity_completions)
    activity_completions.filter_map { |completion| completion.result.failed }.first || flunk('No failed completion')
  end

  def first_canceled_result(activity_completions)
    activity_completions.filter_map { |completion| completion.result.cancelled }.first || flunk('Not canceled')
  end

  def first_attrs(events, attrs_method)
    events.filter_map { |event| event.public_send(attrs_method) }.first || flunk("No event with #{attrs_method}")
  end

  def assert_reference(payload)
    assert References.reference?(payload), "Expected a reference, got metadata #{payload.metadata.to_h}"
  end
end
