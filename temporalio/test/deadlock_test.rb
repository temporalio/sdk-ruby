# frozen_string_literal: true

require 'securerandom'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

class DeadlockTest < Test
  class BasicActivity < Temporalio::Activity::Definition
    def execute(value)
      value
    end
  end

  class DeadlockTimeoutOverrideExecutor < Temporalio::Worker::WorkflowExecutor::ThreadPool
    def initialize(deadlock_timeout)
      super()
      @deadlock_timeout = deadlock_timeout
    end

    def _validate_worker(workflow_worker, worker_state)
      # Fairly hacky, but allows us to run this test without taking 5+ seconds
      worker_state.instance_variable_set(:@deadlock_timeout, @deadlock_timeout)
      super
    end
  end

  class DeadlockTimeoutInFutureWorkflow < Temporalio::Workflow::Definition
    def execute
      reached_activity = false

      Temporalio::Workflow::Future.new do
        Temporalio::Workflow.execute_activity(BasicActivity, 0, start_to_close_timeout: 10)
      end

      future = Temporalio::Workflow::Future.new do
        # Do blocking sleep to trigger deadlock detection when using non-standard executor
        Temporalio::Workflow::Unsafe.durable_scheduler_disabled { sleep(0.2) }
        reached_activity = true
        Temporalio::Workflow.execute_activity(BasicActivity, 1, start_to_close_timeout: 10)
      end

      Temporalio::Workflow.wait_condition(cancellation: nil) { reached_activity || future.done? }
      Temporalio::Workflow.sleep(0.1)
      Temporalio::Workflow.wait_condition { false }
    end
  end

  def test_deadlock_in_future_fails_workflow_task_and_replays_on_new_worker
    task_queue = "tq-#{SecureRandom.uuid}"
    worker1 = Temporalio::Worker.new(
      client: env.client,
      task_queue:,
      workflows: [DeadlockTimeoutInFutureWorkflow],
      activities: [BasicActivity],
      workflow_executor: DeadlockTimeoutOverrideExecutor.new(0.05)
    )
    handle = worker1.run do
      handle = env.client.start_workflow(
        DeadlockTimeoutInFutureWorkflow,
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      assert_eventually_task_fail(handle:, message_contains: 'Potential deadlock detected')
      handle
    end
    events_before_replay = handle.fetch_history_events.to_a
    completed_workflow_tasks = events_before_replay.count(&:workflow_task_completed_event_attributes)
    failed_workflow_tasks = events_before_replay.count(&:workflow_task_failed_event_attributes)

    worker2 = Temporalio::Worker.new(
      client: env.client,
      task_queue:,
      workflows: [DeadlockTimeoutInFutureWorkflow],
      activities: [BasicActivity],
      max_cached_workflows: 0
    )
    worker2.run do
      assert_eventually(timeout: 20.0) do
        events = handle.fetch_history_events.to_a
        new_task_failure = events.select(&:workflow_task_failed_event_attributes).drop(failed_workflow_tasks).first
        if new_task_failure
          flunk(
            'New workflow task failure found: ' \
            "#{new_task_failure.workflow_task_failed_event_attributes.failure.message}"
          )
        end
        assert_operator events.count(&:workflow_task_completed_event_attributes), :>, completed_workflow_tasks
      end
    end
  ensure
    handle&.terminate
  end
end
