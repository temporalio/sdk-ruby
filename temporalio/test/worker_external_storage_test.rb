# frozen_string_literal: true

require 'base64_codec'
require 'in_memory_storage_driver'
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

  private

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
