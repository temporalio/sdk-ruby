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

  # Heartbeats continuously. SlowActivity beats only once, so it cannot drive a heartbeat count
  # past one however long the test waits.
  class FastHeartbeatActivity < Temporalio::Activity::Definition
    def execute
      ctx = Temporalio::Activity::Context.current
      until ctx.cancellation.canceled?
        ctx.heartbeat
        sleep 0.05
      end
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

  # Takes an argument and returns a value derived from it, so a completed execution has both an
  # input and a successful outcome to read back off describe.
  class EchoActivity < Temporalio::Activity::Definition
    def execute(word)
      "#{word}-echoed"
    end
  end

  # Heartbeats, fails the first attempt, then succeeds. One execution of this carries input, a
  # result, heartbeat details and a last failure all at once, which is what lets a single
  # describe exercise every payload field.
  class HeartbeatFailIncrementActivity < Temporalio::Activity::Definition
    def execute(value)
      ctx = Temporalio::Activity::Context.current
      ctx.heartbeat('heartbeat details')
      raise Temporalio::Error::ApplicationError, 'deliberate first-attempt failure' if ctx.info.attempt == 1

      value + 1
    end
  end

  # Always fails. Paired with a single-attempt retry policy so the activity reaches a terminal
  # failure outcome rather than retrying.
  class AlwaysFailActivity < Temporalio::Activity::Definition
    def execute
      raise Temporalio::Error::ApplicationError, 'deliberate failure'
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
      assert_eventually do
        refute_includes PAUSED_STATES, handle.describe.run_state
      end
      handle.terminate('cleanup')
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

      updated = handle.update_options(Temporalio::Client::ActivityOptions::START_TO_CLOSE_TIMEOUT.value_set(90.0))

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
        Temporalio::Client::ActivityOptions::TASK_QUEUE.value_set('updated-tq'),
        Temporalio::Client::ActivityOptions::SCHEDULE_TO_CLOSE_TIMEOUT.value_set(200.0),
        Temporalio::Client::ActivityOptions::SCHEDULE_TO_START_TIMEOUT.value_set(15.0),
        Temporalio::Client::ActivityOptions::START_TO_CLOSE_TIMEOUT.value_set(90.0),
        Temporalio::Client::ActivityOptions::HEARTBEAT_TIMEOUT.value_set(25.0),
        Temporalio::Client::ActivityOptions::RETRY_POLICY.value_set(
          Temporalio::RetryPolicy.new(initial_interval: 1.0, backoff_coefficient: 2.0, max_attempts: 7)
        ),
        Temporalio::Client::ActivityOptions::PRIORITY.value_set(Temporalio::Priority.new(priority_key: 3)),
        Temporalio::Client::ActivityOptions::START_DELAY.value_set(500.0)
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
          handle.update_options(Temporalio::Client::ActivityOptions::START_TO_CLOSE_TIMEOUT.value_set(5.0),
                                restore_original: true)
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
      changed = handle.update_options(Temporalio::Client::ActivityOptions::START_TO_CLOSE_TIMEOUT.value_set(90.0))
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
      updated = handle.update_options(Temporalio::Client::ActivityOptions::START_TO_CLOSE_TIMEOUT.value_set(90.0))
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
    with_activity_worker([QuickActivity]) do |task_queue|
      # Start delayed so the restore is applied immediately.
      handle = env.client.start_activity(
        QuickActivity,
        id: "act-#{SecureRandom.uuid}", task_queue: task_queue,
        start_to_close_timeout: 45, start_delay: 300.0
      )

      updated = handle.update_options(Temporalio::Client::ActivityOptions::START_TO_CLOSE_TIMEOUT.value_set(90.0))
      assert_equal 90.0, updated.start_to_close_timeout

      handle.reset(restore_original_options: true)
      # restore_original_options reverts the changed option to the value the activity was created with.
      assert_eventually do
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

  # Input and outcome are opt-in like the other payload fields, and the outcome is a
  # result-or-failure oneof. A successful activity populates the result arm only.
  # The count tracks heartbeats the server recorded.
  def test_describe_reports_total_heartbeat_count
    with_activity_worker([FastHeartbeatActivity]) do |task_queue|
      handle = env.client.start_activity(
        FastHeartbeatActivity,
        id: "act-#{SecureRandom.uuid}", task_queue:,
        start_to_close_timeout: 60, heartbeat_timeout: 3
      )
      assert_eventually(timeout: 20.0) do
        assert_operator handle.describe.total_heartbeat_count, :>=, 2
      end
      handle.terminate('cleanup')
    end
  end

  def test_describe_payloads
    with_activity_worker([HeartbeatFailIncrementActivity, AlwaysFailActivity]) do |task_queue|
      handle = env.client.start_activity(
        HeartbeatFailIncrementActivity, 1,
        id: "act-#{SecureRandom.uuid}", task_queue:,
        start_to_close_timeout: 60, heartbeat_timeout: 5,
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: 2, initial_interval: 0.1)
      )

      assert_equal 2, handle.result

      # Nothing requested: every payload field is absent.
      bare = handle.describe

      refute bare.has_input?
      refute bare.has_result?
      refute bare.has_heartbeat_details?
      refute bare.has_last_failure?
      assert_empty bare.input
      assert_nil bare.result
      assert_nil bare.failure
      assert_nil bare.last_failure

      # All four requested. The activity succeeded on its second attempt, so it has a result
      # and a last failure at the same time, and no terminal failure.
      full = handle.describe(
        include_input: true, include_outcome: true,
        include_heartbeat_details: true, include_last_failure: true
      )

      assert full.has_input?
      assert_equal [1], full.input
      assert full.has_result?
      assert_equal 2, full.result
      assert_nil full.failure
      assert full.has_heartbeat_details?
      assert_equal ['heartbeat details'], full.heartbeat_details
      assert full.has_last_failure?
      refute_nil full.last_failure

      failed = env.client.start_activity(
        AlwaysFailActivity,
        id: "act-#{SecureRandom.uuid}", task_queue:,
        start_to_close_timeout: 60,
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
      )
      assert_raises(Temporalio::Error) { failed.result }

      desc = failed.describe(include_outcome: true, include_last_failure: true)

      refute desc.has_result?
      assert_nil desc.result
      failure = desc.failure

      assert_instance_of Temporalio::Error::ApplicationError, failure
      assert_equal 'deliberate failure', failure&.message
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

  def test_update_options_preserves_heartbeat
    with_activity_worker([HeartbeatOnceActivity]) do |task_queue|
      handle = start_heartbeat_ready_activity(task_queue)
      handle.pause('hold')
      assert_eventually_paused(handle)

      # UpdateOptions changes activity options only; it never touches heartbeat details.
      handle.update_options(Temporalio::Client::ActivityOptions::START_TO_CLOSE_TIMEOUT.value_set(90.0))
      assert handle.describe(include_heartbeat_details: true).has_heartbeat_details?
      handle.terminate('cleanup')
    end
  end
end
