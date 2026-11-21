# frozen_string_literal: true

require 'in_memory_storage_driver'
require 'securerandom'
require 'temporalio/client'
require 'temporalio/client/schedule'
require 'temporalio/converters/external_storage'
require 'temporalio/converters/storage_driver_workflow_info'
require 'test'

class ClientScheduleExternalStorageTest < Test
  def test_update_sends_unchanged_values_as_described
    with_stored_schedule do |handle, driver|
      before = handle.describe.raw_description.schedule.action.start_workflow
      stored_before = driver.stored.size

      2.times do
        handle.update do |input|
          schedule = input.description.schedule
          Temporalio::Client::Schedule::Update.new(
            schedule: schedule.with(state: Temporalio::Client::Schedule::State.new(note: 'changed', paused: true))
          )
        end
      end

      assert_equal stored_before, driver.stored.size
      desc = handle.describe
      assert_equal 'changed', desc.schedule.state.note
      after = desc.raw_description.schedule.action.start_workflow
      assert_equal before.input, after.input
      assert_equal before.memo, after.memo
      assert_equal before.header, after.header
      assert_equal before.user_metadata, after.user_metadata
    end
  end

  def test_update_stores_only_changed_values
    with_stored_schedule do |handle, driver|
      before = handle.describe.raw_description.schedule.action.start_workflow
      stored_before = driver.stored.size

      handle.update do |input|
        schedule = input.description.schedule
        Temporalio::Client::Schedule::Update.new(
          schedule: schedule.with(
            action: schedule.action.with(args: ['new-arg'], static_summary: 'new-summary') # steep:ignore
          )
        )
      end

      assert_equal stored_before + 2, driver.stored.size
      desc = handle.describe
      action = desc.schedule.action #: Temporalio::Client::Schedule::Action::StartWorkflow
      assert_equal ['new-arg'], action.args
      assert_equal 'new-summary', action.static_summary
      assert_equal 'the-details', action.static_details
      after = desc.raw_description.schedule.action.start_workflow
      assert_equal before.memo, after.memo
      assert_equal before.header, after.header
      assert_equal before.user_metadata.details, after.user_metadata.details
    end
  end

  def test_update_stores_values_changed_in_place
    with_stored_schedule do |handle, driver|
      stored_before = driver.stored.size

      handle.update do |input|
        action = input.description.schedule.action #: Temporalio::Client::Schedule::Action::StartWorkflow
        action.args[0] = 'changed-arg'
        action.memo&.[]=('memo-key', 'changed-memo')
        Temporalio::Client::Schedule::Update.new(schedule: input.description.schedule)
      end

      assert_equal stored_before + 2, driver.stored.size
      action = handle.describe.schedule.action #: Temporalio::Client::Schedule::Action::StartWorkflow
      assert_equal ['changed-arg'], action.args
      assert_equal({ 'memo-key' => 'changed-memo' }, action.memo)
    end
  end

  def test_action_payloads_are_stored_for_the_scheduled_workflow
    with_stored_schedule do |handle, driver|
      action = handle.describe.schedule.action #: Temporalio::Client::Schedule::Action::StartWorkflow
      scheduled_workflow_target = Temporalio::Converters::StorageDriverWorkflowInfo.new(
        namespace: env.client.namespace, id: action.id, type: 'some-workflow'
      )
      %w[the-arg the-memo the-summary the-details the-header].each do |value|
        assert_equal [scheduled_workflow_target], driver.targets_of_payloads_with_data(value.to_json), value
      end

      handle.update do |input|
        schedule = input.description.schedule
        Temporalio::Client::Schedule::Update.new(
          schedule: schedule.with(action: schedule.action.with(args: ['new-arg'])) # steep:ignore
        )
      end
      assert_equal [scheduled_workflow_target], driver.targets_of_payloads_with_data('new-arg'.to_json)
    end
  end

  def test_schedule_memo_is_stored_for_the_scheduled_workflow
    driver = InMemoryStorageDriver.new
    workflow_id = "wf-#{SecureRandom.uuid}"
    handle = client_with_storage(driver).create_schedule(
      "sched-#{SecureRandom.uuid}",
      Temporalio::Client::Schedule.new(
        action: Temporalio::Client::Schedule::Action::StartWorkflow.new(
          'some-workflow', id: workflow_id, task_queue: "tq-#{SecureRandom.uuid}"
        ),
        spec: Temporalio::Client::Schedule::Spec.new,
        state: Temporalio::Client::Schedule::State.new(paused: true)
      ),
      memo: { 'schedule-memo-key' => 'the-schedule-memo' }
    )
    scheduled_workflow_target = Temporalio::Converters::StorageDriverWorkflowInfo.new(
      namespace: env.client.namespace, id: workflow_id, type: 'some-workflow'
    )
    assert_equal [scheduled_workflow_target], driver.targets_of_payloads_with_data('the-schedule-memo'.to_json)
  ensure
    handle&.delete
  end

  private

  def client_with_storage(driver)
    Temporalio::Client.new(
      **env.client.options.with(
        data_converter: Temporalio::Converters::DataConverter.new(
          external_storage: Temporalio::Converters::ExternalStorage.new(drivers: [driver], payload_size_threshold: 0)
        )
      ).to_h
    )
  end

  def with_stored_schedule
    driver = InMemoryStorageDriver.new
    client = client_with_storage(driver)
    handle = client.create_schedule(
      "sched-#{SecureRandom.uuid}",
      Temporalio::Client::Schedule.new(
        action: Temporalio::Client::Schedule::Action::StartWorkflow.new(
          'some-workflow', 'the-arg',
          id: "wf-#{SecureRandom.uuid}",
          task_queue: "tq-#{SecureRandom.uuid}",
          static_summary: 'the-summary',
          static_details: 'the-details',
          memo: { 'memo-key' => 'the-memo' },
          headers: { 'header-key' => 'the-header' }
        ),
        spec: Temporalio::Client::Schedule::Spec.new,
        state: Temporalio::Client::Schedule::State.new(paused: true)
      )
    )
    yield handle, driver
  ensure
    handle&.delete
  end
end
