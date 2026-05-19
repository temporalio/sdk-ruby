# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

class ClientActivityTest < Test
  class SimpleActivity < Temporalio::Activity::Definition
    activity_arg_hint :saa_arg
    activity_result_hint :saa_result

    def execute(value)
      "saa: #{value}"
    end
  end

  class VoidActivity < Temporalio::Activity::Definition
    def execute
      # Returns nil implicitly.
    end
  end

  class SlowActivity < Temporalio::Activity::Definition
    def execute
      Temporalio::Activity::Context.current.heartbeat
      until Temporalio::Activity::Context.current.cancellation.canceled?
        sleep 0.1
      end
      raise Temporalio::Error::CanceledError, 'canceled'
    end
  end

  class FailingActivity < Temporalio::Activity::Definition
    def execute
      raise Temporalio::Error::ApplicationError.new('intentional failure', 'detail1', non_retryable: true)
    end
  end

  # Sleeps for `delay_seconds` then returns "delayed:#{delay}". Used by tests that need
  # observable blocking behavior on the client side.
  class DelayedActivity < Temporalio::Activity::Definition
    def execute(delay_seconds)
      sleep(delay_seconds)
      "delayed:#{delay_seconds}"
    end
  end

  # Run a worker with the supplied activities for the body of the block and yield the task_queue.
  def with_activity_worker(activities, &block)
    task_queue = "saa-tq-#{SecureRandom.uuid}"
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: task_queue,
      activities: activities
    )
    worker.run { yield task_queue }
  end

  def test_execute_activity_simple_with_result
    with_activity_worker([SimpleActivity]) do |task_queue|
      result = env.client.execute_activity(
        SimpleActivity,
        'hi',
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      assert_equal 'saa: hi', result
    end
  end

  def test_execute_activity_void_result
    with_activity_worker([VoidActivity]) do |task_queue|
      result = env.client.execute_activity(
        VoidActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      assert_nil result
    end
  end

  def test_execute_activity_by_name
    with_activity_worker([SimpleActivity]) do |task_queue|
      result = env.client.execute_activity(
        'SimpleActivity',
        'by-name',
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      assert_equal 'saa: by-name', result
    end
  end

  def test_start_activity_already_started_throws
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        SlowActivity,
        id: activity_id,
        task_queue: task_queue,
        start_to_close_timeout: 30
      )
      err = assert_raises(Temporalio::Error::ActivityAlreadyStartedError) do
        env.client.start_activity(
          SlowActivity,
          id: activity_id,
          task_queue: task_queue,
          start_to_close_timeout: 30,
          id_conflict_policy: Temporalio::ActivityIDConflictPolicy::FAIL
        )
      end
      assert_equal activity_id, err.activity_id
      handle.terminate
    end
  end

  def test_only_schedule_to_close_timeout_is_valid
    with_activity_worker([SimpleActivity]) do |task_queue|
      result = env.client.execute_activity(
        SimpleActivity,
        'only-schedule-to-close',
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        schedule_to_close_timeout: 10
      )
      assert_equal 'saa: only-schedule-to-close', result
    end
  end

  def test_only_start_to_close_timeout_is_valid
    with_activity_worker([SimpleActivity]) do |task_queue|
      result = env.client.execute_activity(
        SimpleActivity,
        'only-start-to-close',
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      assert_equal 'saa: only-start-to-close', result
    end
  end

  def test_get_activity_result_failure_throws_activity_failed_error
    with_activity_worker([FailingActivity]) do |task_queue|
      err = assert_raises(Temporalio::Error::ActivityFailedError) do
        env.client.execute_activity(
          FailingActivity,
          id: "act-#{SecureRandom.uuid}",
          task_queue: task_queue,
          start_to_close_timeout: 10
        )
      end
      assert_instance_of Temporalio::Error::ApplicationError, err.cause
      assert_equal 'intentional failure', err.cause.message
      assert_equal ['detail1'], err.cause.details
    end
  end

  def test_describe_running_and_terminated_is_accurate
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        SlowActivity,
        id: activity_id,
        task_queue: task_queue,
        start_to_close_timeout: 30
      )

      desc = handle.describe
      assert_equal activity_id, desc.activity_id
      assert_equal 'SlowActivity', desc.activity_type
      # Status should be RUNNING (1).
      assert_equal Temporalio::Client::ActivityExecutionStatus::RUNNING, desc.status

      handle.terminate('test-termination')
      # After terminate, status should reach TERMINATED eventually.
      assert_eventually do
        d = handle.describe
        assert_equal Temporalio::Client::ActivityExecutionStatus::TERMINATED, d.status
      end
    end
  end

  def test_describe_raw_info_matches_typed_accessors
    with_activity_worker([SimpleActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      env.client.execute_activity(
        SimpleActivity,
        'raw-info',
        id: activity_id,
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      desc = env.client.activity_handle(activity_id).describe
      assert_equal desc.raw_description.info.activity_id, desc.activity_id
      assert_equal desc.raw_description.info.activity_type.name, desc.activity_type
      assert_equal desc.raw_description.info.task_queue, desc.task_queue
      assert_equal desc.raw_description.info.attempt, desc.attempt
    end
  end

  def test_state_transition_count_is_present
    with_activity_worker([SimpleActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      env.client.execute_activity(
        SimpleActivity,
        'stc',
        id: activity_id,
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      desc = env.client.activity_handle(activity_id).describe
      # Completed activities will have non-zero state transitions.
      assert_kind_of Integer, desc.state_transition_count
      assert_operator desc.state_transition_count, :>, 0
    end
  end

  def test_terminate_running_activity_result_throws_terminated_error
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        SlowActivity,
        id: activity_id,
        task_queue: task_queue,
        start_to_close_timeout: 30
      )
      handle.terminate('intentional')
      err = assert_raises(Temporalio::Error::ActivityFailedError) do
        handle.result
      end
      assert_instance_of Temporalio::Error::TerminatedError, err.cause
    end
  end

  def test_get_activity_result_polls_until_activity_completes
    # Genuinely test the blocking behavior of result(): start a slow activity, call result,
    # and assert both that we waited long enough for the activity to finish AND that we got
    # the right value back. A SimpleActivity-based test wouldn't prove polling at all because
    # the activity is already done by the time result() asks the server.
    delay = 2.0
    with_activity_worker([DelayedActivity]) do |task_queue|
      handle = env.client.start_activity(
        DelayedActivity, delay,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 30
      )
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = handle.result
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
      assert_equal "delayed:#{delay}", result
      assert_operator elapsed, :>=, delay * 0.75,
                      "Expected result() to block for at least #{delay * 0.75}s (proving long-poll), got #{elapsed}s"
    end
  end

  def test_list_activities_simple_list_is_accurate
    with_activity_worker([SimpleActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      env.client.execute_activity(
        SimpleActivity,
        'listed',
        id: activity_id,
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      assert_eventually do
        found = env.client.list_activities("ActivityId=\"#{activity_id}\"").to_a
        refute_empty found, "Expected at least one activity matching ActivityId=#{activity_id}"
        assert_equal activity_id, found.first.activity_id
      end
    end
  end

  def test_count_activities_simple_count_is_accurate
    with_activity_worker([SimpleActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      env.client.execute_activity(
        SimpleActivity,
        'counted',
        id: activity_id,
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      assert_eventually do
        count = env.client.count_activities("ActivityId=\"#{activity_id}\"")
        assert_kind_of Temporalio::Client::ActivityExecutionCount, count
        assert_equal 1, count.count
      end
    end
  end

  def test_get_handle_with_nil_run_id
    with_activity_worker([SimpleActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      env.client.execute_activity(
        SimpleActivity,
        'nil-run',
        id: activity_id,
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      handle = env.client.activity_handle(activity_id) # run_id: nil
      desc = handle.describe
      assert_equal activity_id, desc.activity_id
      assert_equal 'saa: nil-run', handle.result
    end
  end

  def test_activity_handle_describe_terminate_smoke
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        SlowActivity,
        id: activity_id,
        task_queue: task_queue,
        start_to_close_timeout: 30
      )
      desc = handle.describe
      assert_equal activity_id, desc.activity_id
      handle.terminate('smoke-test')
    end
  end

  def test_start_activity_id_reuse_policy_reject_duplicate_throws
    with_activity_worker([SimpleActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      # First start completes successfully.
      env.client.execute_activity(
        SimpleActivity, 'first',
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 10,
        id_reuse_policy: Temporalio::ActivityIDReusePolicy::REJECT_DUPLICATE
      )
      # Second start with REJECT_DUPLICATE on the same ID rejects.
      assert_raises(Temporalio::Error::ActivityAlreadyStartedError) do
        env.client.start_activity(
          SimpleActivity, 'second',
          id: activity_id, task_queue: task_queue, start_to_close_timeout: 10,
          id_reuse_policy: Temporalio::ActivityIDReusePolicy::REJECT_DUPLICATE
        )
      end
    end
  end

  def test_start_activity_id_reuse_policy_reject_duplicate_overridable_by_later_request
    with_activity_worker([SimpleActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      # First start with REJECT_DUPLICATE, completes.
      env.client.execute_activity(
        SimpleActivity, 'first',
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 10,
        id_reuse_policy: Temporalio::ActivityIDReusePolicy::REJECT_DUPLICATE
      )
      # Second start with same ID also REJECT_DUPLICATE → rejected.
      assert_raises(Temporalio::Error::ActivityAlreadyStartedError) do
        env.client.start_activity(
          SimpleActivity, 'second',
          id: activity_id, task_queue: task_queue, start_to_close_timeout: 10,
          id_reuse_policy: Temporalio::ActivityIDReusePolicy::REJECT_DUPLICATE
        )
      end
      # Third start with ALLOW_DUPLICATE → succeeds, overriding the prior REJECT_DUPLICATE.
      result = env.client.execute_activity(
        SimpleActivity, 'third',
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 10,
        id_reuse_policy: Temporalio::ActivityIDReusePolicy::ALLOW_DUPLICATE
      )
      assert_equal 'saa: third', result
    end
  end

  def test_describe_timeouts_round_trip
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        SlowActivity,
        id: activity_id, task_queue: task_queue,
        schedule_to_close_timeout: 60,
        schedule_to_start_timeout: 30,
        start_to_close_timeout: 45,
        heartbeat_timeout: 5
      )
      desc = handle.describe
      assert_in_delta 60.0, desc.schedule_to_close_timeout, 0.5
      assert_in_delta 30.0, desc.schedule_to_start_timeout, 0.5
      assert_in_delta 45.0, desc.start_to_close_timeout, 0.5
      assert_in_delta 5.0, desc.heartbeat_timeout, 0.5
      handle.terminate('cleanup')
    end
  end

  def test_describe_priority_round_trip
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      priority = Temporalio::Priority.new(priority_key: 3)
      handle = env.client.start_activity(
        SlowActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 30,
        priority: priority
      )
      desc = handle.describe
      assert_equal 3, desc.priority.priority_key
      handle.terminate('cleanup')
    end
  end

  def test_describe_static_summary_and_details_set_at_start
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        SlowActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 30,
        static_summary: 'my activity summary',
        static_details: 'my activity details'
      )
      desc = handle.describe
      assert_equal 'my activity summary', desc.static_summary
      assert_equal 'my activity details', desc.static_details
      handle.terminate('cleanup')
    end
  end

  def test_describe_retry_policy_round_trip
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      retry_policy = Temporalio::RetryPolicy.new(
        initial_interval: 1.5,
        backoff_coefficient: 2.5,
        max_interval: 30.0,
        max_attempts: 7
      )
      handle = env.client.start_activity(
        SlowActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 30,
        retry_policy: retry_policy
      )
      desc = handle.describe
      rp = desc.retry_policy
      assert_in_delta 1.5, rp.initial_interval, 0.01
      assert_in_delta 2.5, rp.backoff_coefficient, 0.01
      assert_in_delta 30.0, rp.max_interval, 0.01
      assert_equal 7, rp.max_attempts
      handle.terminate('cleanup')
    end
  end

  def test_cancel_running_activity_transitions_to_canceled
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        SlowActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 30,
        heartbeat_timeout: 5
      )
      # Wait until the activity has actually started before cancelling.
      assert_eventually do
        desc = handle.describe
        assert_operator desc.attempt, :>=, 1
      end
      handle.cancel('test-cancel')
      # Activity observes cancellation, raises CanceledError; server records CANCELED.
      assert_eventually do
        desc = handle.describe
        assert_equal Temporalio::Client::ActivityExecutionStatus::CANCELED, desc.status
      end
      # handle.result should raise ActivityFailedError with a CanceledError cause.
      err = assert_raises(Temporalio::Error::ActivityFailedError) { handle.result }
      assert_instance_of Temporalio::Error::CanceledError, err.cause
    end
  end

  def test_describe_canceled_reason_after_cancel
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        SlowActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 30
      )
      handle.cancel('user-cancel-reason')
      assert_eventually do
        desc = handle.describe
        assert_equal 'user-cancel-reason', desc.canceled_reason
      end
      # SlowActivity observes cancellation and raises CanceledError; activity completes itself, no terminate needed.
    end
  end

  def test_describe_attempt_starts_at_1
    with_activity_worker([SimpleActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      env.client.execute_activity(
        SimpleActivity, 'attempt',
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 10
      )
      desc = env.client.activity_handle(activity_id).describe
      assert_equal 1, desc.attempt
    end
  end

  def test_id_conflict_policy_use_existing_returns_handle_for_running
    with_activity_worker([SlowActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      first = env.client.start_activity(
        SlowActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 30
      )
      # Second start with same id + USE_EXISTING returns a handle to the running activity.
      second = env.client.start_activity(
        SlowActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 30,
        id_conflict_policy: Temporalio::ActivityIDConflictPolicy::USE_EXISTING
      )
      # Both handles target the same activity_id (same activity_run_id from the server too).
      assert_equal first.id, second.id
      assert_equal first.run_id, second.run_id
      first.terminate('cleanup')
    end
  end
end
