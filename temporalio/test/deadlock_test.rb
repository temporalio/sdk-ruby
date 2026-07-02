# frozen_string_literal: true

require 'google/protobuf'
require 'securerandom'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

class DeadlockTest < Test
  module SchedulerDrainProbe
    class << self
      attr_accessor :queue
    end

    def run_until_all_yielded
      super
    ensure
      queue = SchedulerDrainProbe.queue
      @instance.illegal_call_tracing_disabled { queue << true } if queue
    end
  end

  unless Temporalio::Internal::Worker::WorkflowInstance::Scheduler.ancestors.include?(SchedulerDrainProbe)
    Temporalio::Internal::Worker::WorkflowInstance::Scheduler.prepend(SchedulerDrainProbe)
  end

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

  class ProtobufObjectCacheMutexWorkflow < Temporalio::Workflow::Definition
    REACHED_PROTOBUF_CACHE = Queue.new

    class << self
      attr_accessor :protobuf_mutex_held
    end

    def execute
      Temporalio::Workflow::Future.new do
        Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled { REACHED_PROTOBUF_CACHE << true }
        nil until self.class.protobuf_mutex_held
        Google::Protobuf::Internal::OBJECT_CACHE.try_add(Object.new, Object.new)
        Temporalio::Workflow.execute_activity(BasicActivity, 'done', start_to_close_timeout: 10)
      end.wait
    end
  end

  class ProtobufObjectCachePartialCommandsWorkflow < Temporalio::Workflow::Definition
    ACTIVITY_COUNT = 6
    BLOCK_AFTER_ACTIVITY_COUNT = 3
    REACHED_PROTOBUF_CACHE = Queue.new

    class << self
      attr_accessor :protobuf_mutex_held
    end

    def execute
      futures = []
      ACTIVITY_COUNT.times do |index|
        if index == BLOCK_AFTER_ACTIVITY_COUNT
          Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled { REACHED_PROTOBUF_CACHE << true }
          Temporalio::Workflow.wait_condition(cancellation: nil) { true }
          nil until self.class.protobuf_mutex_held
          Google::Protobuf::Internal::OBJECT_CACHE.try_add(Object.new, Object.new)
        end
        futures << Temporalio::Workflow::Future.new do
          Temporalio::Workflow.execute_activity(BasicActivity, index, start_to_close_timeout: 10)
        end
      end
      Temporalio::Workflow::Future.all_of(*futures).wait
    end
  end

  def setup
    super
    ProtobufObjectCacheMutexWorkflow::REACHED_PROTOBUF_CACHE.clear
    ProtobufObjectCacheMutexWorkflow.protobuf_mutex_held = false
    ProtobufObjectCachePartialCommandsWorkflow::REACHED_PROTOBUF_CACHE.clear
    ProtobufObjectCachePartialCommandsWorkflow.protobuf_mutex_held = false
    SchedulerDrainProbe.queue = nil
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

  def test_protobuf_object_cache_mutex_does_not_complete_workflow_task_while_blocked
    # @type var release_mutex: (^() -> void)?
    release_mutex = nil
    execute_workflow(
      ProtobufObjectCacheMutexWorkflow,
      activities: [BasicActivity]
    ) do |handle|
      Timeout.timeout(10) { ProtobufObjectCacheMutexWorkflow::REACHED_PROTOBUF_CACHE.pop }
      release_mutex = hold_protobuf_object_cache_mutex
      ProtobufObjectCacheMutexWorkflow.protobuf_mutex_held = true
      wait_for_protobuf_object_cache_mutex_waiter
      (release_mutex || raise).call
      release_mutex = nil

      # @type var events: Array[untyped]
      events = []
      assert_eventually(timeout: 10.0) do
        events = handle.fetch_history_events.to_a
        assert events.any?(&:workflow_task_completed_event_attributes)
      end

      workflow_task_completed = events.find(&:workflow_task_completed_event_attributes)
      activity_scheduled = events.find(&:activity_task_scheduled_event_attributes)
      refute_nil(
        activity_scheduled,
        'Workflow task completed while a workflow fiber was blocked on the protobuf ObjectCache mutex'
      )
      assert_equal workflow_task_completed.event_id + 1, activity_scheduled.event_id
    ensure
      ProtobufObjectCacheMutexWorkflow.protobuf_mutex_held = true
      release_mutex&.call
      begin
        handle.terminate
      rescue Temporalio::Error::RPCError
        # Ignore cleanup races if the workflow closed before terminate arrived.
      end
    end
  end

  def test_protobuf_object_cache_mutex_does_not_emit_partial_command_batch
    task_queue = "tq-#{SecureRandom.uuid}"
    # @type var release_mutex: (^() -> void)?
    release_mutex = nil
    # @type var handle: untyped
    handle = nil
    scheduler_drained = Queue.new
    SchedulerDrainProbe.queue = scheduler_drained
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue:,
      workflows: [ProtobufObjectCachePartialCommandsWorkflow],
      activities: [BasicActivity],
      workflow_executor: Temporalio::Worker::WorkflowExecutor::ThreadPool.new(max_threads: 1)
    )

    worker.run do
      handle = env.client.start_workflow(
        ProtobufObjectCachePartialCommandsWorkflow,
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      Timeout.timeout(10) { ProtobufObjectCachePartialCommandsWorkflow::REACHED_PROTOBUF_CACHE.pop }
      release_mutex = hold_protobuf_object_cache_mutex
      ProtobufObjectCachePartialCommandsWorkflow.protobuf_mutex_held = true
      wait_for_protobuf_object_cache_mutex_waiter
      Timeout.timeout(10.0) { scheduler_drained.pop }
      (release_mutex || raise).call
      release_mutex = nil

      # @type var events: Array[untyped]
      events = []
      assert_eventually(timeout: 10.0) do
        events = handle.fetch_history_events.to_a
        assert(events.any? do |event|
          %i[
            EVENT_TYPE_WORKFLOW_TASK_COMPLETED
            EVENT_TYPE_WORKFLOW_TASK_FAILED
          ].include?(event.event_type)
        end)
      end

      first_completed_index = events.index { |event| event.event_type == :EVENT_TYPE_WORKFLOW_TASK_COMPLETED }
      first_failed_index = events.index { |event| event.event_type == :EVENT_TYPE_WORKFLOW_TASK_FAILED }
      unless first_failed_index && (!first_completed_index || first_failed_index < first_completed_index)
        refute_nil first_completed_index, "History event types: #{events.map(&:event_type).inspect}"
        completed_index = first_completed_index || raise
        scheduled_count = (events[(completed_index + 1)..] || []).take_while do |event|
          event.event_type == :EVENT_TYPE_ACTIVITY_TASK_SCHEDULED
        end.size
        assert_equal(
          ProtobufObjectCachePartialCommandsWorkflow::ACTIVITY_COUNT,
          scheduled_count,
          'Workflow task completed with a partial activity schedule command batch while a workflow fiber was ' \
          'blocked on the protobuf ObjectCache mutex'
        )
      end
    ensure
      SchedulerDrainProbe.queue = nil
      ProtobufObjectCachePartialCommandsWorkflow.protobuf_mutex_held = true
      release_mutex&.call
      begin
        handle&.terminate
      rescue Temporalio::Error::RPCError
        # Ignore cleanup races if the workflow closed before terminate arrived.
      end
    end
  end

  def hold_protobuf_object_cache_mutex
    mutex = Google::Protobuf::Internal::OBJECT_CACHE.instance_variable_get(:@mutex)
    acquired = Queue.new
    release = Queue.new
    released = false
    holder = Thread.new do
      mutex.synchronize do
        acquired << true
        release.pop
      end
    end
    acquired.pop

    lambda do
      unless released
        released = true
        release << true
      end
      holder.join
    end
  end

  def wait_for_protobuf_object_cache_mutex_waiter
    assert_eventually(timeout: 10.0, interval: 0.01) do
      assert(
        Thread.list.any? do |thread|
          next false if thread == Thread.current

          thread.backtrace_locations&.any? do |location|
            location.path.end_with?('/google/protobuf/internal/object_cache.rb') &&
              location.label.include?('synchronize')
          end
        end,
        'Expected a workflow thread to block on protobuf ObjectCache mutex'
      )
    end
  end
end
