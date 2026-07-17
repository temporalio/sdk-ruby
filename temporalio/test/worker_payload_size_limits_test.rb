# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/error'
require 'temporalio/runtime'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

# Payload/memo size-limit enforcement lives in sdk-core. These tests only assert that the Ruby
# plumbing reaches core: an oversized worker completion is failed proactively, and the
# disable_payload_error_limit opt-out lets the oversized payload reach (and be rejected by) the
# server. The warning channel is asserted via the default log filter.
class WorkerPayloadSizeLimitsTest < Test
  PAYLOAD_ERROR_LIMIT = 10 * 1024

  class LargePayloadActivity < Temporalio::Activity::Definition
    def execute(_data)
      nil
    end
  end

  class LargePayloadWorkflow < Temporalio::Workflow::Definition
    def execute(activity_input_data_size, workflow_output_data_size)
      if activity_input_data_size.positive?
        Temporalio::Workflow.execute_activity(
          LargePayloadActivity,
          'i' * activity_input_data_size,
          schedule_to_close_timeout: 5
        )
      end
      'o' * workflow_output_data_size
    end
  end

  # Regression guard for the log-filter fix: the default filter must admit temporalio_common (where
  # validate_payload_limits logs the [TMPRL1103] warning) at the core level, otherwise payload-limit
  # warnings would be silently dropped.
  def test_default_log_filter_admits_temporalio_common
    filter = Temporalio::Runtime::LoggingFilterOptions.new(core_level: 'WARN', other_level: 'ERROR')
    assert_includes filter._to_bridge, 'temporalio_common=WARN'
  end

  def with_payload_limited_server
    server = Temporalio::Testing::WorkflowEnvironment.start_local(
      dev_server_extra_args: [
        '--dynamic-config-value', "limit.blobSize.error=#{PAYLOAD_ERROR_LIMIT}",
        # The server only enforces the error limit for payloads that also exceed the warn limit, so
        # the warn limit must be below the error limit.
        '--dynamic-config-value', 'limit.blobSize.warn=2048'
      ]
    )
    begin
      yield server
    ensure
      server.shutdown
    end
  end

  def test_oversized_payload_fails_task
    with_payload_limited_server do |server|
      worker = Temporalio::Worker.new(
        client: server.client,
        task_queue: "tq-#{SecureRandom.uuid}",
        activities: [LargePayloadActivity],
        workflows: [LargePayloadWorkflow]
      )
      # Rather than send the oversized workflow result, core proactively fails the workflow task with a
      # PAYLOADS_TOO_LARGE cause. The task keeps failing, so the workflow ultimately fails by execution timeout.
      worker.run do
        handle = server.client.start_workflow(
          LargePayloadWorkflow, 0, PAYLOAD_ERROR_LIMIT + 1024,
          id: "wf-#{SecureRandom.uuid}",
          task_queue: worker.task_queue,
          execution_timeout: 3
        )
        assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }

        # Confirm the driving cause: the worker reported a workflow task failure with PAYLOADS_TOO_LARGE.
        # @type var events: Array[untyped]
        events = handle.fetch_history_events.to_a
        assert(events.any? do |event|
          event.event_type == :EVENT_TYPE_WORKFLOW_TASK_FAILED &&
            event.workflow_task_failed_event_attributes.cause == :WORKFLOW_TASK_FAILED_CAUSE_PAYLOADS_TOO_LARGE
        end)
      end
    end
  end

  def test_disable_payload_error_limit_sends_to_server
    with_payload_limited_server do |server|
      worker = Temporalio::Worker.new(
        client: server.client,
        task_queue: "tq-#{SecureRandom.uuid}",
        activities: [LargePayloadActivity],
        workflows: [LargePayloadWorkflow],
        disable_payload_error_limit: true
      )
      # With the opt-out, core does not pre-fail; the oversized activity input reaches the server,
      # which rejects the ScheduleActivityTask command and fails the workflow.
      worker.run do
        handle = server.client.start_workflow(
          LargePayloadWorkflow, PAYLOAD_ERROR_LIMIT + 1024, 0,
          id: "wf-#{SecureRandom.uuid}",
          task_queue: worker.task_queue,
          execution_timeout: 3
        )
        assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      end
    end
  end
end
