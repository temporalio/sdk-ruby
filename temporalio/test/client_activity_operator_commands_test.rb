# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

# Tests for the standalone-activity operator commands on ActivityHandle:
# pause / unpause / reset / update_options. Each asserts an observable server state change.
class ClientActivityOperatorCommandsTest < Test
  # Long-running activity that heartbeats and runs until cancellation.
  class SlowActivity < Temporalio::Activity::Definition
    def execute
      Temporalio::Activity::Context.current.heartbeat
      sleep 0.1 until Temporalio::Activity::Context.current.cancellation.canceled?
      raise Temporalio::Error::CanceledError, 'canceled'
    end
  end

  # Returns immediately. Used together with a start delay so it can be paused while scheduled
  # (before it ever runs) and then resumed to a successful completion.
  class QuickActivity < Temporalio::Activity::Definition
    def execute
      'resumed'
    end
  end

  # Fails the first two attempts so retries are forced, then succeeds on the third. Used to exercise
  # reset against an activity that has recorded more than one attempt.
  class FailThenSucceedActivity < Temporalio::Activity::Definition
    def execute
      if Temporalio::Activity::Context.current.info.attempt < 3
        raise Temporalio::Error::ApplicationError, 'retryable failure'
      end

      'done'
    end
  end

  # Always fails (on every server attempt). Used to drive the attempt counter above 1 so unpause with
  # reset_attempts can be observed pulling it back to 1.
  class AlwaysFailActivity < Temporalio::Activity::Definition
    def execute
      raise Temporalio::Error::ApplicationError,
            "fail attempt #{Temporalio::Activity::Context.current.info.attempt}"
    end
  end

  # Records heartbeat details on the first attempt then fails, so the details are persisted and the
  # activity backs off (observable + pausable while scheduled). Later attempts just run without
  # heartbeating, so once the details are cleared by reset_heartbeat they stay cleared.
  class HeartbeatThenStopActivity < Temporalio::Activity::Definition
    def execute
      ctx = Temporalio::Activity::Context.current
      if ctx.info.attempt == 1
        ctx.heartbeat('hb-details')
        raise Temporalio::Error::ApplicationError, 'force retry'
      end
      sleep 0.1 until ctx.cancellation.canceled?
      raise Temporalio::Error::CanceledError, 'canceled'
    end
  end

  # A running activity does not transition straight to PAUSED on pause: the server records
  # PAUSE_REQUESTED and only moves to PAUSED once the worker acknowledges (drops the attempt). A
  # long-running heartbeating activity that has not yet noticed the pause stays in PAUSE_REQUESTED,
  # so both states count as "paused" for an observability assertion.
  PAUSED_STATES = [
    Temporalio::Client::PendingActivityState::PAUSED,
    Temporalio::Client::PendingActivityState::PAUSE_REQUESTED
  ].freeze

  def assert_eventually_paused(handle)
    assert_eventually do
      assert_includes PAUSED_STATES, handle.describe.run_state
    end
  end

  def with_activity_worker(activities, &)
    task_queue = "saa-tq-#{SecureRandom.uuid}"
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: task_queue,
      activities: activities
    )
    worker.run { yield task_queue }
  end

  # Start a SlowActivity and wait until it has actually started running on the worker.
  def start_running_slow_activity(task_queue, **kwargs)
    activity_id = "act-#{SecureRandom.uuid}"
    handle = env.client.start_activity(
      SlowActivity,
      id: activity_id, task_queue: task_queue, start_to_close_timeout: 60,
      heartbeat_timeout: 30, **kwargs
    )
    assert_eventually do
      desc = handle.describe
      assert_equal Temporalio::Client::PendingActivityState::STARTED, desc.run_state
    end
    handle
  end

  def test_pause_shows_paused
    with_activity_worker([SlowActivity]) do |task_queue|
      handle = start_running_slow_activity(task_queue)
      handle.pause('test-pause-reason')
      assert_eventually_paused(handle)
      handle.terminate('cleanup')
    end
  end

  def test_unpause_resumes
    with_activity_worker([QuickActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      # Start with a long delay so the activity sits in SCHEDULED and can be paused before it runs.
      handle = env.client.start_activity(
        QuickActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 60,
        start_delay: 30.0
      )
      handle.pause('pause-before-unpause')
      # A not-yet-started (scheduled) activity transitions fully to PAUSED.
      assert_eventually do
        assert_equal Temporalio::Client::PendingActivityState::PAUSED, handle.describe.run_state
      end

      handle.unpause
      # After unpause the activity proceeds and completes successfully (proving it resumed).
      assert_equal 'resumed', handle.result
    end
  end

  def test_reset
    with_activity_worker([FailThenSucceedActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        FailThenSucceedActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 60,
        retry_policy: Temporalio::RetryPolicy.new(
          initial_interval: 0.2, backoff_coefficient: 1.0, max_interval: 0.2, max_attempts: 50
        )
      )
      # Wait until the activity has recorded more than one attempt (i.e. it has retried).
      assert_eventually do
        assert_operator handle.describe.attempt, :>, 1
      end

      handle.reset
      # After reset the attempt counter goes back to the start.
      assert_eventually do
        assert_equal 1, handle.describe.attempt
      end
      handle.terminate('cleanup')
    end
  end

  def test_update_options_respects_mask
    with_activity_worker([SlowActivity]) do |task_queue|
      handle = start_running_slow_activity(
        task_queue,
        start_to_close_timeout: 45,
        schedule_to_close_timeout: 120
      )

      updated = handle.update_options(start_to_close_timeout: 90.0)

      # Returned options: only start_to_close changed; schedule_to_close kept its original value.
      assert_in_delta 90.0, updated.start_to_close_timeout, 0.5
      assert_in_delta 120.0, updated.schedule_to_close_timeout, 0.5

      # Confirm via describe that the partial update was applied server-side.
      assert_eventually do
        desc = handle.describe
        assert_in_delta 90.0, desc.start_to_close_timeout, 0.5
        assert_in_delta 120.0, desc.schedule_to_close_timeout, 0.5
      end
      handle.terminate('cleanup')
    end
  end

  def test_update_options_all_fields
    with_activity_worker([QuickActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      # Start delayed so the activity stays SCHEDULED (never runs) while we update every option and
      # observe each one applied.
      handle = env.client.start_activity(
        QuickActivity,
        id: activity_id, task_queue: task_queue,
        schedule_to_close_timeout: 100, start_to_close_timeout: 30, start_delay: 300.0
      )

      updated = handle.update_options(
        schedule_to_close_timeout: 200.0,
        schedule_to_start_timeout: 15.0,
        start_to_close_timeout: 90.0,
        heartbeat_timeout: 25.0,
        retry_policy: Temporalio::RetryPolicy.new(initial_interval: 1.0, backoff_coefficient: 2.0, max_attempts: 7),
        priority: Temporalio::Priority.new(priority_key: 3)
      )

      # Every field is settable and lands: the returned options reflect each new value.
      assert_in_delta 200.0, updated.schedule_to_close_timeout, 0.5
      assert_in_delta 15.0, updated.schedule_to_start_timeout, 0.5
      assert_in_delta 90.0, updated.start_to_close_timeout, 0.5
      assert_in_delta 25.0, updated.heartbeat_timeout, 0.5
      assert_equal 7, updated.retry_policy&.max_attempts
      assert_equal 3, updated.priority.priority_key

      # And describe reflects them server-side.
      desc = handle.describe
      assert_in_delta 200.0, desc.schedule_to_close_timeout, 0.5
      assert_in_delta 15.0, desc.schedule_to_start_timeout, 0.5
      assert_in_delta 90.0, desc.start_to_close_timeout, 0.5
      assert_in_delta 25.0, desc.heartbeat_timeout, 0.5
      assert_equal 7, desc.retry_policy&.max_attempts
      assert_equal 3, desc.priority.priority_key

      handle.terminate('cleanup')
    end
  end

  def test_update_options_restore_original_exclusive
    with_activity_worker([SlowActivity]) do |task_queue|
      handle = start_running_slow_activity(task_queue)
      # Wrap the RPC so we can prove it is never reached when the validation fails.
      ws = env.client.workflow_service
      reached = false
      original = ws.method(:update_activity_execution_options)
      ws.define_singleton_method(:update_activity_execution_options) do |req, **kwargs|
        reached = true
        original.call(req, **kwargs)
      end
      begin
        err = assert_raises(ArgumentError) do
          handle.update_options(restore_original: true, start_to_close_timeout: 5.0)
        end
        assert_match(/restore_original cannot be combined/i, err.message)
        refute reached, 'update_activity_execution_options RPC should not be reached when validation fails'
      ensure
        ws.singleton_class.send(:remove_method, :update_activity_execution_options)
      end
      handle.terminate('cleanup')
    end
  end

  def test_update_options_restore_original
    with_activity_worker([SlowActivity]) do |task_queue|
      handle = start_running_slow_activity(task_queue, start_to_close_timeout: 45)

      # Change an option away from the original.
      changed = handle.update_options(start_to_close_timeout: 90.0)
      assert_in_delta 90.0, changed.start_to_close_timeout, 0.5

      # restore_original alone reverts to the value the activity was created with.
      restored = handle.update_options(restore_original: true)
      assert_in_delta 45.0, restored.start_to_close_timeout, 0.5
      handle.terminate('cleanup')
    end
  end

  def test_unpause_resets_attempts
    with_activity_worker([AlwaysFailActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        AlwaysFailActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 60,
        retry_policy: Temporalio::RetryPolicy.new(
          initial_interval: 0.2, backoff_coefficient: 1.0, max_interval: 0.2, max_attempts: 50
        )
      )
      # Wait until the activity has recorded more than one attempt (i.e. it has retried).
      assert_eventually do
        assert_operator handle.describe.attempt, :>, 1
      end

      handle.pause('hold')
      assert_eventually_paused(handle)

      handle.unpause(reset_attempts: true)
      # reset_attempts pulls the attempt counter back to 1.
      assert_eventually do
        assert_equal 1, handle.describe.attempt
      end
      handle.terminate('cleanup')
    end
  end

  def test_reset_keeps_paused
    with_activity_worker([QuickActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      # Start delayed so the activity sits SCHEDULED and pauses to a true PAUSED state (not the
      # PAUSE_REQUESTED of a running activity), which is what keep_paused must preserve across reset.
      handle = env.client.start_activity(
        QuickActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 60, start_delay: 30.0
      )
      handle.pause('hold')
      assert_eventually do
        assert_equal Temporalio::Client::PendingActivityState::PAUSED, handle.describe.run_state
      end

      handle.reset(keep_paused: true)
      # keep_paused means the activity remains paused across the reset.
      assert_eventually do
        assert_equal Temporalio::Client::PendingActivityState::PAUSED, handle.describe.run_state
      end
      handle.terminate('cleanup')
    end
  end

  def test_reset_restores_original_options
    with_activity_worker([SlowActivity]) do |task_queue|
      handle = start_running_slow_activity(task_queue, start_to_close_timeout: 45)

      updated = handle.update_options(start_to_close_timeout: 90.0)
      assert_in_delta 90.0, updated.start_to_close_timeout, 0.5

      handle.reset(restore_original_options: true)
      # restore_original_options reverts the changed option to the value the activity was created with.
      assert_eventually do
        assert_in_delta 45.0, handle.describe.start_to_close_timeout, 0.5
      end
      handle.terminate('cleanup')
    end
  end

  # Start a HeartbeatThenStopActivity and wait until its first attempt has recorded heartbeat details
  # and the activity is backing off (scheduled), so it can be paused into a true PAUSED state.
  def start_backed_off_heartbeat_activity(task_queue)
    activity_id = "act-#{SecureRandom.uuid}"
    handle = env.client.start_activity(
      HeartbeatThenStopActivity,
      id: activity_id, task_queue: task_queue, start_to_close_timeout: 60, heartbeat_timeout: 30,
      retry_policy: Temporalio::RetryPolicy.new(
        initial_interval: 10.0, backoff_coefficient: 1.0, max_interval: 10.0, max_attempts: 50
      )
    )
    assert_eventually do
      assert handle.describe.has_heartbeat_details?
    end
    handle
  end

  def test_unpause_resets_heartbeat
    with_activity_worker([HeartbeatThenStopActivity]) do |task_queue|
      handle = start_backed_off_heartbeat_activity(task_queue)
      handle.pause('hold')
      assert_eventually_paused(handle)

      # Unpause re-dispatches the next attempt with heartbeat details cleared; that attempt does not
      # heartbeat, so the details stay cleared and are observable.
      handle.unpause(reset_heartbeat: true)
      assert_eventually do
        refute handle.describe.has_heartbeat_details?
      end
      handle.terminate('cleanup')
    end
  end

  def test_reset_resets_heartbeat
    with_activity_worker([HeartbeatThenStopActivity]) do |task_queue|
      handle = start_backed_off_heartbeat_activity(task_queue)
      handle.pause('hold')
      assert_eventually_paused(handle)

      # keep_paused so no new attempt runs to re-record details; reset_heartbeat clears them in place.
      handle.reset(reset_heartbeat: true, keep_paused: true)
      assert_eventually do
        refute handle.describe.has_heartbeat_details?
      end
      handle.terminate('cleanup')
    end
  end
end
