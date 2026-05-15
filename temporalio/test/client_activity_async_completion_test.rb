# frozen_string_literal: true

require 'securerandom'
require 'temporalio/activity'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

# Async completion of standalone activities. Mirrors the workflow-scoped async-completion tests in
# worker_activity_test.rb but targets standalone-form ActivityIDReferences (constructed via
# `ActivityIDReference.for_standalone(activity_id:, activity_run_id:)`).
class ClientActivityAsyncCompletionTest < Test
  # Activity that signals readiness on a queue, then raises CompleteAsyncError to defer completion to
  # an external async caller. The queue is purely a timing barrier — it tells the test "I've executed
  # and I'm now in the async-pending state, you can complete me." The activity_id/activity_run_id are
  # read from the handle, not from the queue.
  class AsyncCompleteActivity < Temporalio::Activity::Definition
    READY = Queue.new

    def execute
      READY << true
      raise Temporalio::Activity::CompleteAsyncError
    end

    def self.wait_ready
      Timeout.timeout(15) { READY.pop }
    end

    def self.drain
      READY.clear
    end
  end

  def with_async_worker(&block)
    task_queue = "saa-tq-#{SecureRandom.uuid}"
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: task_queue,
      activities: [AsyncCompleteActivity]
    )
    worker.run { yield task_queue }
  end

  def test_async_completion_complete_by_activity_id
    AsyncCompleteActivity.drain
    with_async_worker do |task_queue|
      handle = env.client.start_activity(
        AsyncCompleteActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 30
      )
      AsyncCompleteActivity.wait_ready
      # Standalone reference with activity_run_id omitted — "target the latest run."
      ref = Temporalio::Client::ActivityIDReference.for_standalone(activity_id: handle.id)
      env.client.async_activity_handle(ref).complete('async-done')
      assert_equal 'async-done', handle.result
    end
  end

  def test_async_completion_complete_with_run_id
    AsyncCompleteActivity.drain
    with_async_worker do |task_queue|
      handle = env.client.start_activity(
        AsyncCompleteActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 30
      )
      AsyncCompleteActivity.wait_ready
      ref = Temporalio::Client::ActivityIDReference.for_standalone(
        activity_id: handle.id,
        activity_run_id: handle.run_id
      )
      env.client.async_activity_handle(ref).complete('with-run-id')
      assert_equal 'with-run-id', handle.result
    end
  end

  def test_async_completion_heartbeat_standalone
    AsyncCompleteActivity.drain
    with_async_worker do |task_queue|
      handle = env.client.start_activity(
        AsyncCompleteActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 30,
        heartbeat_timeout: 30
      )
      AsyncCompleteActivity.wait_ready
      ref = Temporalio::Client::ActivityIDReference.for_standalone(
        activity_id: handle.id,
        activity_run_id: handle.run_id
      )
      env.client.async_activity_handle(ref).heartbeat('hb-1', 'hb-2')
      assert_equal %w[hb-1 hb-2],
                   env.client.data_converter.from_payloads(handle.describe.raw_info.heartbeat_details)
      env.client.async_activity_handle(ref).complete('done-after-heartbeat')
      assert_equal 'done-after-heartbeat', handle.result
    end
  end

  def test_async_completion_fail_standalone
    AsyncCompleteActivity.drain
    with_async_worker do |task_queue|
      # max_attempts: 1 ensures the async fail terminates the activity rather than triggering a retry
      # (which would re-execute the activity, hit CompleteAsyncError again, and loop).
      handle = env.client.start_activity(
        AsyncCompleteActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 30,
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
      )
      AsyncCompleteActivity.wait_ready
      ref = Temporalio::Client::ActivityIDReference.for_standalone(
        activity_id: handle.id,
        activity_run_id: handle.run_id
      )
      env.client.async_activity_handle(ref).fail(
        Temporalio::Error::ApplicationError.new('async-fail-reason', non_retryable: true)
      )
      err = assert_raises(Temporalio::Error::ActivityFailedError) { handle.result }
      assert_instance_of Temporalio::Error::ApplicationError, err.cause
      assert_equal 'async-fail-reason', err.cause.message
    end
  end

  def test_async_completion_heartbeat_and_fail_standalone
    AsyncCompleteActivity.drain
    with_async_worker do |task_queue|
      handle = env.client.start_activity(
        AsyncCompleteActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 30,
        heartbeat_timeout: 30,
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
      )
      AsyncCompleteActivity.wait_ready
      ref = Temporalio::Client::ActivityIDReference.for_standalone(
        activity_id: handle.id,
        activity_run_id: handle.run_id
      )
      env.client.async_activity_handle(ref).heartbeat('hb-1', 'hb-2')
      assert_equal %w[hb-1 hb-2],
                   env.client.data_converter.from_payloads(handle.describe.raw_info.heartbeat_details)
      env.client.async_activity_handle(ref).fail(
        Temporalio::Error::ApplicationError.new('hb-then-fail', non_retryable: true)
      )
      err = assert_raises(Temporalio::Error::ActivityFailedError) { handle.result }
      assert_instance_of Temporalio::Error::ApplicationError, err.cause
      assert_equal 'hb-then-fail', err.cause.message
    end
  end

  def test_async_completion_report_cancellation_standalone
    AsyncCompleteActivity.drain
    with_async_worker do |task_queue|
      handle = env.client.start_activity(
        AsyncCompleteActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 30,
        heartbeat_timeout: 30
      )
      AsyncCompleteActivity.wait_ready
      ref = Temporalio::Client::ActivityIDReference.for_standalone(
        activity_id: handle.id,
        activity_run_id: handle.run_id
      )
      handle.cancel('please-cancel')
      env.client.async_activity_handle(ref).report_cancellation
      err = assert_raises(Temporalio::Error::ActivityFailedError) { handle.result }
      assert_instance_of Temporalio::Error::CanceledError, err.cause
    end
  end
end
