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
      assert_operator desc.state_transition_count, :>=, 0
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
    with_activity_worker([SimpleActivity]) do |task_queue|
      activity_id = "act-#{SecureRandom.uuid}"
      handle = env.client.start_activity(
        SimpleActivity,
        'polled',
        id: activity_id,
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      # result blocks until completion via long-poll
      assert_equal 'saa: polled', handle.result
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
        assert_operator count.count, :>=, 1
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
    end
  end

  def test_activity_handle_describe_cancel_terminate_smoke
    # Use start + describe + terminate (not cancel — cancel needs heartbeating to take effect).
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

end
