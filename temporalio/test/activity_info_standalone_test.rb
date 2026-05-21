# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

# Verify Activity::Info exposes the standalone-vs-workflow distinction correctly from inside the activity body.
#
# Two activity definitions report their info to a captured value; the tests then assert what the
# captured info contains based on how the activity was scheduled (standalone via Client#execute_activity vs.
# from a workflow via Workflow.execute_activity).
class ActivityInfoStandaloneTest < Test
  CAPTURED = Queue.new

  class ReportInfoActivity < Temporalio::Activity::Definition
    def execute
      info = Temporalio::Activity::Context.current.info
      CAPTURED << {
        in_workflow: info.in_workflow?,
        activity_run_id: info.activity_run_id,
        workflow_id: info.workflow_id,
        workflow_run_id: info.workflow_run_id,
        workflow_type: info.workflow_type,
        namespace: info.namespace
      }
      'reported'
    end
  end

  class CallActivityWorkflow < Temporalio::Workflow::Definition
    def execute(task_queue)
      Temporalio::Workflow.execute_activity(ReportInfoActivity, start_to_close_timeout: 10, task_queue: task_queue)
    end
  end

  def capture_next
    Timeout.timeout(15) { CAPTURED.pop }
  end

  def drain_captures
    CAPTURED.clear
  end

  def test_info_standalone_fields_set_correctly
    drain_captures
    task_queue = "saa-tq-#{SecureRandom.uuid}"
    worker = Temporalio::Worker.new(client: env.client, task_queue: task_queue, activities: [ReportInfoActivity])
    worker.run do
      env.client.execute_activity(
        ReportInfoActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
    end
    captured = capture_next
    refute captured[:in_workflow], 'standalone activity should report in_workflow? == false'
    refute_nil captured[:activity_run_id], 'standalone activity should have a non-nil activity_run_id'
    assert_nil captured[:workflow_id], 'standalone activity should have nil workflow_id'
    assert_nil captured[:workflow_run_id], 'standalone activity should have nil workflow_run_id'
    assert_nil captured[:workflow_type], 'standalone activity should have nil workflow_type'
    assert_equal env.client.namespace, captured[:namespace]
  end

  def test_info_workflow_scheduled_fields_set_correctly
    drain_captures
    task_queue = "saa-tq-#{SecureRandom.uuid}"
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: task_queue,
      workflows: [CallActivityWorkflow],
      activities: [ReportInfoActivity]
    )
    worker.run do
      handle = env.client.start_workflow(
        CallActivityWorkflow,
        task_queue,
        id: "wf-#{SecureRandom.uuid}",
        task_queue: task_queue
      )
      handle.result
    end
    captured = capture_next
    assert captured[:in_workflow], 'workflow-scheduled activity should report in_workflow? == true'
    refute_nil captured[:workflow_id], 'workflow-scheduled activity should have non-nil workflow_id'
    refute_nil captured[:workflow_run_id], 'workflow-scheduled activity should have non-nil workflow_run_id'
    refute_nil captured[:workflow_type], 'workflow-scheduled activity should have non-nil workflow_type'
    assert_equal 'CallActivityWorkflow', captured[:workflow_type]
    assert_equal env.client.namespace, captured[:namespace]
  end
end
