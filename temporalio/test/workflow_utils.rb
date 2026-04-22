# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

module WorkflowUtils
  # @type instance: Test

  def execute_workflow(
    workflow,
    *args,
    activities: [],
    more_workflows: [],
    task_queue: "tq-#{SecureRandom.uuid}",
    id: "wf-#{SecureRandom.uuid}",
    search_attributes: nil,
    memo: nil,
    retry_policy: nil,
    workflow_failure_exception_types: [],
    max_cached_workflows: 1000,
    logger: nil,
    client: env.client,
    workflow_payload_codec_thread_pool: nil,
    id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::UNSPECIFIED,
    max_heartbeat_throttle_interval: 60.0,
    task_timeout: nil,
    interceptors: [],
    on_worker_run: nil,
    unsafe_workflow_io_enabled: false,
    priority: Temporalio::Priority.default,
    start_workflow_client: client,
    tuner: Temporalio::Worker::Tuner.create_fixed
  )
    worker = Temporalio::Worker.new(
      client:,
      task_queue:,
      activities:,
      workflows: [workflow] + more_workflows,
      workflow_failure_exception_types:,
      max_cached_workflows:,
      logger: logger || client.options.logger,
      workflow_payload_codec_thread_pool:,
      max_heartbeat_throttle_interval:,
      interceptors:,
      unsafe_workflow_io_enabled:,
      tuner:
    )
    worker.run do
      on_worker_run&.call
      handle = start_workflow_client.start_workflow(
        workflow,
        *args,
        id:,
        task_queue: worker.task_queue,
        search_attributes:,
        memo:,
        retry_policy:,
        id_conflict_policy:,
        task_timeout:,
        priority:
      )
      if block_given?
        yield handle, worker
      else
        handle.result
      end
    end
  end

  def assert_eventually_task_fail(handle:, message_contains: nil)
    assert_eventually do
      event = handle.fetch_history_events.find(&:workflow_task_failed_event_attributes)
      refute_nil event
      assert_includes(event.workflow_task_failed_event_attributes.failure.message, message_contains) if message_contains
      event
    end
  end

  def assert_eventually_complete(handle:, timeout: 10, interval: 0.2)
    start_time = Time.now
    loop do
      events = handle.fetch_history_events

      task_fail_event = events.find(&:workflow_task_failed_event_attributes)
      if task_fail_event
        flunk(
          'Workflow task failed instead of completing: ' \
          "#{task_fail_event.workflow_task_failed_event_attributes.failure.message}"
        )
      end

      return handle.result if events.any?(&:workflow_execution_completed_event_attributes)

      flunk('Timed out waiting for workflow completion') if Time.now - start_time > timeout

      sleep(interval)
    end
  end
end
