# frozen_string_literal: true

require 'base64_codec'
require 'in_memory_storage_driver'
require 'securerandom'
require 'temporalio/client'
require 'temporalio/converters/external_storage'
require 'temporalio/error'
require 'temporalio/internal/external_storage_references'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

class WorkerExternalStorageTest < Test
  References = Temporalio::Internal::ExternalStorageReferences

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

  def test_worker_retrieve_failure_fails_the_task_and_is_retried
    assert_storage_failure_retried(FailOnceStorageDriver.new(fail_retrieve: true), 'Intentional retrieve failure')
  end

  def test_worker_store_failure_fails_the_task_and_is_retried
    assert_storage_failure_retried(
      FailOnceStorageDriver.new(fail_store_containing: 'done'), 'Failed encoding completion: Intentional store failure'
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

    error = assert_raises(RuntimeError) do
      client.start_workflow(EchoWorkflow, 'start-input', id: "wf-#{SecureRandom.uuid}", task_queue: 'unused')
    end
    assert_equal 'Intentional store failure', error.message
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

  private

  def assert_storage_failure_retried(driver, failure_message)
    execute_workflow(
      EchoWorkflow, 'start-input',
      client: client_with_storage(driver),
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      assert_equal 'start-input done', handle.result
      failure = first_attrs(handle.fetch_history_events, :workflow_task_failed_event_attributes).failure
      assert_equal failure_message, failure.message
    end
  end

  def client_with_storage(driver, payload_codec: nil)
    data_converter = Temporalio::Converters::DataConverter.new(
      payload_codec:,
      external_storage: Temporalio::Converters::ExternalStorage.new(drivers: [driver], payload_size_threshold: 0)
    )
    Temporalio::Client.new(**env.client.options.with(data_converter:).to_h) # steep:ignore InsufficientKeywordArguments
  end

  def first_attrs(events, attrs_method)
    events.filter_map { |event| event.public_send(attrs_method) }.first || flunk("No event with #{attrs_method}")
  end

  def assert_reference(payload)
    assert References.reference?(payload), "Expected a reference, got metadata #{payload.metadata.to_h}"
  end
end
