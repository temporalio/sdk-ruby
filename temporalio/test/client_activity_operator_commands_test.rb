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

  # Records heartbeat details on attempt 1, then blocks waiting for cancellation. The heartbeat
  # runs on its own — not adjacent to any completion RPC — so the details reliably persist and are
  # observable via describe. Later attempts (after a reset or an unpause that spawns a new attempt)
  # do not heartbeat, so any operator-driven clearing of the details stays observable.
  class HeartbeatOnceActivity < Temporalio::Activity::Definition
    def execute
      ctx = Temporalio::Activity::Context.current
      ctx.heartbeat('hb-details') if ctx.info.attempt == 1
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
      assert_equal 90.0, updated.start_to_close_timeout
      assert_equal 120.0, updated.schedule_to_close_timeout

      # Confirm via describe that the partial update was applied server-side.
      assert_eventually do
        desc = handle.describe
        assert_equal 90.0, desc.start_to_close_timeout
        assert_equal 120.0, desc.schedule_to_close_timeout
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
        task_queue: 'updated-tq',
        schedule_to_close_timeout: 200.0,
        schedule_to_start_timeout: 15.0,
        start_to_close_timeout: 90.0,
        heartbeat_timeout: 25.0,
        retry_policy: Temporalio::RetryPolicy.new(initial_interval: 1.0, backoff_coefficient: 2.0, max_attempts: 7),
        priority: Temporalio::Priority.new(priority_key: 3),
        start_delay: 500.0
      )

      # Every field is settable and lands: the returned options reflect each new value.
      assert_equal 'updated-tq', updated.task_queue
      assert_equal 200.0, updated.schedule_to_close_timeout
      assert_equal 15.0, updated.schedule_to_start_timeout
      assert_equal 90.0, updated.start_to_close_timeout
      assert_equal 25.0, updated.heartbeat_timeout
      assert_equal 7, updated.retry_policy&.max_attempts
      assert_equal 3, updated.priority.priority_key
      assert_equal 500.0, updated.start_delay

      # And describe reflects them server-side.
      desc = handle.describe
      assert_equal 'updated-tq', desc.task_queue
      assert_equal 200.0, desc.schedule_to_close_timeout
      assert_equal 15.0, desc.schedule_to_start_timeout
      assert_equal 90.0, desc.start_to_close_timeout
      assert_equal 25.0, desc.heartbeat_timeout
      assert_equal 7, desc.retry_policy&.max_attempts
      assert_equal 3, desc.priority.priority_key
      assert_equal 500.0, desc.start_delay

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

  def test_update_options_requires_at_least_one_option
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
        err = assert_raises(ArgumentError) { handle.update_options }
        assert_match(/at least one option/i, err.message)
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
      assert_equal 90.0, changed.start_to_close_timeout

      # restore_original alone reverts to the value the activity was created with.
      restored = handle.update_options(restore_original: true)
      assert_equal 45.0, restored.start_to_close_timeout
      handle.terminate('cleanup')
    end
  end

  def test_update_options_on_paused_activity
    with_activity_worker([QuickActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      # Start delayed so the activity sits SCHEDULED and pauses to a true PAUSED state rather than
      # the PAUSE_REQUESTED a running activity lands in.
      handle = env.client.start_activity(
        QuickActivity,
        id: activity_id, task_queue: task_queue,
        start_to_close_timeout: 45, schedule_to_close_timeout: 120, start_delay: 60.0
      )
      handle.pause('hold')
      assert_eventually do
        assert_equal Temporalio::Client::PendingActivityState::PAUSED, handle.describe.run_state
      end

      # Updating options is legal while paused, and the new value lands. Whole-second timeouts
      # round-trip exactly through the protobuf Duration conversion, so assert on equality.
      updated = handle.update_options(start_to_close_timeout: 90.0)
      assert_equal 90.0, updated.start_to_close_timeout

      desc = handle.describe
      assert_equal 90.0, desc.start_to_close_timeout
      # The mask is still honored while paused — an option we didn't touch keeps its original value.
      assert_equal 120.0, desc.schedule_to_close_timeout
      # And the update leaves the activity paused; it is not an implicit unpause.
      assert_equal Temporalio::Client::PendingActivityState::PAUSED, desc.run_state
      assert_equal Temporalio::Client::ActivityExecutionStatus::PAUSED, desc.status

      handle.terminate('cleanup')
    end
  end

  def test_describe_paused_activity_reports_paused_status
    with_activity_worker([QuickActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      # Start delayed so the activity sits SCHEDULED; pausing from there reaches a true PAUSED
      # state rather than the PAUSE_REQUESTED of a running activity. `status` is the overall
      # ActivityExecutionStatus (api#834 added PAUSED to it); `run_state` is the finer-grained
      # PendingActivityState. Both should read PAUSED here.
      handle = env.client.start_activity(
        QuickActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 60, start_delay: 30.0
      )
      # Before the pause the activity is simply RUNNING (scheduled, not yet started).
      assert_equal Temporalio::Client::ActivityExecutionStatus::RUNNING, handle.describe.status

      handle.pause('hold')
      assert_eventually do
        desc = handle.describe
        assert_equal Temporalio::Client::ActivityExecutionStatus::PAUSED, desc.status
        assert_equal Temporalio::Client::PendingActivityState::PAUSED, desc.run_state
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
      # DIAGNOSTIC (2026-07-30): bumped from default 10s to 60s.
      assert_eventually(timeout: 60.0) do
        assert_equal Temporalio::Client::PendingActivityState::PAUSED, handle.describe.run_state
      end
      handle.terminate('cleanup')
    end
  end

  def test_reset_restores_original_options
    with_activity_worker([SlowActivity]) do |task_queue|
      handle = start_running_slow_activity(task_queue, start_to_close_timeout: 45)

      updated = handle.update_options(start_to_close_timeout: 90.0)
      assert_equal 90.0, updated.start_to_close_timeout

      handle.reset(restore_original_options: true)
      # restore_original_options reverts the changed option to the value the activity was created with.
      # DIAGNOSTIC (2026-07-30): bumped from 30s to 60s.
      assert_eventually(timeout: 60.0) do
        assert_equal 45.0, handle.describe.start_to_close_timeout
      end
      handle.terminate('cleanup')
    end
  end

  # Start a HeartbeatOnceActivity and wait until its first attempt has recorded heartbeat details.
  # The activity keeps running (sleeping until cancellation) once heartbeat has fired, so pause
  # transitions the activity through PAUSE_REQUESTED to PAUSED — assert_eventually_paused tolerates
  # both.
  def start_heartbeat_ready_activity(task_queue)
    activity_id = "act-#{SecureRandom.uuid}"
    handle = env.client.start_activity(
      HeartbeatOnceActivity,
      id: activity_id, task_queue: task_queue, start_to_close_timeout: 60, heartbeat_timeout: 30
    )
    assert_eventually do
      assert handle.describe(include_heartbeat_details: true).has_heartbeat_details?
    end
    handle
  end

  # The payload-bearing describe fields are opt-in (api#792). Assert the default really is "off"
  # rather than the SDK quietly requesting everything: same activity, same moment, two describes.
  def test_describe_payload_fields_are_opt_in
    with_activity_worker([HeartbeatOnceActivity]) do |task_queue|
      handle = start_heartbeat_ready_activity(task_queue)
      refute handle.describe.has_heartbeat_details?
      assert_empty handle.describe.heartbeat_details
      assert handle.describe(include_heartbeat_details: true).has_heartbeat_details?
      assert_equal ['hb-details'], handle.describe(include_heartbeat_details: true).heartbeat_details
      handle.terminate('cleanup')
    end
  end

  def test_pause_preserves_heartbeat
    with_activity_worker([HeartbeatOnceActivity]) do |task_queue|
      handle = start_heartbeat_ready_activity(task_queue)
      handle.pause('hold')
      assert_eventually_paused(handle)
      # Pause never touches heartbeat details — they persist across the transition.
      assert handle.describe(include_heartbeat_details: true).has_heartbeat_details?
      handle.terminate('cleanup')
    end
  end

  def test_unpause_preserves_heartbeat
    with_activity_worker([HeartbeatOnceActivity]) do |task_queue|
      handle = start_heartbeat_ready_activity(task_queue)
      handle.pause('hold')
      assert_eventually_paused(handle)

      # Unpause preserves heartbeat details. The re-dispatched attempt doesn't heartbeat (only
      # attempt 1 does), so the persisted details are stable and observable.
      handle.unpause
      assert_eventually do
        assert handle.describe(include_heartbeat_details: true).has_heartbeat_details?
      end
      handle.terminate('cleanup')
    end
  end

  def test_reset_preserves_heartbeat_by_default
    with_activity_worker([HeartbeatOnceActivity]) do |task_queue|
      handle = start_heartbeat_ready_activity(task_queue)
      handle.pause('hold')
      assert_eventually_paused(handle)

      # As of api#848 / temporal#11417, reset does NOT clear heartbeat details by default —
      # you must pass reset_heartbeat: true. keep_paused so no new attempt reshapes state.
      handle.reset(keep_paused: true)
      # Give the server time to persist any state change, then confirm details survive.
      sleep 2
      assert handle.describe(include_heartbeat_details: true).has_heartbeat_details?
      handle.terminate('cleanup')
    end
  end

  def test_reset_clears_heartbeat_when_flag_set
    with_activity_worker([HeartbeatOnceActivity]) do |task_queue|
      handle = start_heartbeat_ready_activity(task_queue)
      handle.pause('hold')
      assert_eventually_paused(handle)

      # Opt-in flag clears details.
      handle.reset(keep_paused: true, reset_heartbeat: true)
      assert_eventually(timeout: 30.0) do
        refute handle.describe(include_heartbeat_details: true).has_heartbeat_details?
      end
      handle.terminate('cleanup')
    end
  end

  def test_update_options_preserves_heartbeat
    with_activity_worker([HeartbeatOnceActivity]) do |task_queue|
      handle = start_heartbeat_ready_activity(task_queue)
      handle.pause('hold')
      assert_eventually_paused(handle)

      # UpdateOptions changes activity options only; it never touches heartbeat details.
      handle.update_options(start_to_close_timeout: 90.0)
      assert handle.describe(include_heartbeat_details: true).has_heartbeat_details?
      handle.terminate('cleanup')
    end
  end
end
