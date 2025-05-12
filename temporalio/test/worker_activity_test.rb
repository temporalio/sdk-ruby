# frozen_string_literal: true

require 'async'
require 'async/notification'
require 'base64'
require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

class WorkerActivityTest < Test
  also_run_all_tests_in_fiber

  class ClassActivity < Temporalio::Activity::Definition
    def execute(name)
      "Hello, #{name}!"
    end
  end

  def test_class
    assert_equal 'Hello, Class!', execute_activity(ClassActivity, 'Class')
  end

  class InstanceActivity < Temporalio::Activity::Definition
    def initialize(greeting)
      @greeting = greeting
    end

    def execute(name)
      "#{@greeting}, #{name}!"
    end
  end

  def test_instance
    assert_equal 'Howdy, Instance!', execute_activity(InstanceActivity.new('Howdy'), 'Instance')
  end

  def test_block
    activity = Temporalio::Activity::Definition::Info.new(name: 'BlockActivity') { |name| "Greetings, #{name}!" }
    assert_equal 'Greetings, Block!', execute_activity(activity, 'Block')
  end

  class FiberActivity < Temporalio::Activity::Definition
    attr_reader :waiting_notification, :result_notification

    activity_executor :fiber

    def initialize
      @waiting_notification = Async::Notification.new
      @result_notification = Async::Notification.new
    end

    def execute
      @waiting_notification.signal
      value = @result_notification.wait
      "Hello, #{value}!"
    end
  end

  def test_fiber
    # Tests are doubly executed in threaded and fiber, so we start a new Async block just in case
    Async do |_task|
      activity = FiberActivity.new
      result = execute_activity(activity) do |handle|
        # Wait for activity to reach its waiting point
        activity.waiting_notification.wait
        # Send signal
        activity.result_notification.signal 'Fiber'
        # Wait for result
        handle.result
      end
      flunk('Should have failed') unless Temporalio::Internal::Bridge.fibers_supported
      assert_equal 'Hello, Fiber!', result
    rescue StandardError => e
      raise if Temporalio::Internal::Bridge.fibers_supported
      raise unless e.message.include?('Ruby 3.3 and newer')
    end
  end

  class LoggingActivity < Temporalio::Activity::Definition
    def execute
      # Log and then raise only on first attempt
      Temporalio::Activity::Context.current.logger.info('Test log')
      raise 'Intentional failure' if Temporalio::Activity::Context.current.info.attempt == 1

      'done'
    end
  end

  def test_logging
    out, = safe_capture_io do
      # New logger each time since stdout is replaced
      execute_activity(LoggingActivity, retry_max_attempts: 2, logger: Logger.new($stdout))
    end
    lines = out.split("\n")
    assert(lines.one? { |l| l.include?('Test log') && (l.include?(':attempt=>1') || l.include?('attempt: 1')) })
    assert(lines.one? { |l| l.include?('Test log') && (l.include?(':attempt=>1') || l.include?('attempt: 2')) })
  end

  class CustomNameActivity < Temporalio::Activity::Definition
    activity_name 'my-activity'

    def execute
      'done'
    end
  end

  def test_custom_name
    execute_activity(CustomNameActivity) do |handle|
      assert_equal 'done', handle.result
      assert(handle.fetch_history.events.one? do |e|
        e.activity_task_scheduled_event_attributes&.activity_type&.name == 'my-activity'
      end)
    end
  end

  class DuplicateNameActivity1 < Temporalio::Activity::Definition
  end

  class DuplicateNameActivity2 < Temporalio::Activity::Definition
    activity_name :DuplicateNameActivity1
  end

  def test_duplicate_name
    error = assert_raises(ArgumentError) do
      Temporalio::Worker.new(
        client: env.client,
        task_queue: "tq-#{SecureRandom.uuid}",
        activities: [DuplicateNameActivity1, DuplicateNameActivity2]
      )
    end
    assert_equal 'Multiple activities named DuplicateNameActivity1', error.message
  end

  class UnknownExecutorActivity < Temporalio::Activity::Definition
    activity_executor :some_unknown
  end

  def test_unknown_executor
    error = assert_raises(ArgumentError) do
      Temporalio::Worker.new(
        client: env.client,
        task_queue: "tq-#{SecureRandom.uuid}",
        activities: [UnknownExecutorActivity]
      )
    end
    assert_equal "Unknown executor 'some_unknown'", error.message
  end

  class NotAnActivity # rubocop:disable Lint/EmptyClass
  end

  def test_not_an_activity
    error = assert_raises(ArgumentError) do
      Temporalio::Worker.new(
        client: env.client,
        task_queue: "tq-#{SecureRandom.uuid}",
        activities: [NotAnActivity]
      )
    end
    assert error.message.end_with?('does not extend Temporalio::Activity::Definition')
  end

  class FailureActivity < Temporalio::Activity::Definition
    def execute(form)
      case form
      when 'simple'
        raise 'simple-error'
      when 'argument'
        raise ArgumentError, 'argument-error'
      when 'application'
        raise Temporalio::Error::ApplicationError.new(
          'application-error',
          { foo: 'bar' },
          'detail2',
          type: 'some-error-type',
          non_retryable: true,
          next_retry_delay: 1.23
        )
      end
    end
  end

  def test_failure
    # Check basic error
    error = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_activity(FailureActivity, 'simple') }
    assert_kind_of Temporalio::Error::ActivityError, error.cause
    assert_equal 'FailureActivity', error.cause.activity_type
    assert_kind_of Temporalio::Error::ApplicationError, error.cause.cause
    assert_equal 'simple-error', error.cause.cause.message
    assert_includes error.cause.cause.backtrace.first, 'worker_activity_test.rb'
    assert_equal 'RuntimeError', error.cause.cause.type

    # Check that the error type is properly changed
    error = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_activity(FailureActivity, 'argument') }
    assert_equal 'ArgumentError', error.cause.cause.type

    # Check that application error details are set
    error = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_activity(FailureActivity, 'application') }
    assert_equal 'application-error', error.cause.cause.message
    assert_equal [{ 'foo' => 'bar' }, 'detail2'], error.cause.cause.details
    assert_equal 'some-error-type', error.cause.cause.type
    assert error.cause.cause.non_retryable
    assert_equal 1.23, error.cause.cause.next_retry_delay
  end

  class UnimplementedExecuteActivity < Temporalio::Activity::Definition
  end

  def test_unimplemented_execute
    error = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_activity(UnimplementedExecuteActivity) }
    assert_equal 'Activity did not implement "execute"', error.cause.cause.message
  end

  def test_not_found
    error = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_activity(UnimplementedExecuteActivity, override_name: 'not-found')
    end
    assert error.cause.cause.message.end_with?(
      'is not registered on this worker, available activities: UnimplementedExecuteActivity'
    )
  end

  class MultiParamActivity < Temporalio::Activity::Definition
    def execute(arg1, arg2, arg3)
      "Args: #{arg1}, #{arg2}, #{arg3}"
    end
  end

  def test_multi_param
    assert_equal "Args: #{{ 'foo' => 'bar' }}, 123, baz", # rubocop:disable Lint/LiteralInInterpolation
                 execute_activity(MultiParamActivity, { foo: 'bar' }, 123, 'baz')
  end

  class InfoActivity < Temporalio::Activity::Definition
    def execute
      # Task token is non-utf8 safe string, so we need to base64 it
      info_hash = Temporalio::Activity::Context.current.info.to_h # steep:ignore
      info_hash[:task_token] = Base64.encode64(info_hash[:task_token])
      info_hash
    end
  end

  def test_info
    info_hash = execute_activity(InfoActivity)
    info = Temporalio::Activity::Info.new(**info_hash) # steep:ignore
    refute_nil info.activity_id
    assert_equal 'InfoActivity', info.activity_type
    assert_equal 1, info.attempt
    refute_nil info.current_attempt_scheduled_time
    assert_equal false, info.local?
    refute_nil info.schedule_to_close_timeout
    refute_nil info.scheduled_time
    refute_nil info.current_attempt_scheduled_time
    refute_nil info.start_to_close_timeout
    refute_nil info.started_time
    refute_nil info.task_queue
    refute_nil info.task_token
    refute_nil info.workflow_id
    assert_equal env.client.namespace, info.workflow_namespace
    refute_nil info.workflow_run_id
    assert_equal 'kitchen_sink', info.workflow_type
  end

  class CancellationActivity < Temporalio::Activity::Definition
    attr_reader :canceled

    def initialize(swallow: false)
      @started = Queue.new
      @swallow = swallow
    end

    def execute
      @started.push(nil)
      # Heartbeat every 50ms
      loop do
        sleep(0.05)
        Temporalio::Activity::Context.current.heartbeat
      end
    rescue Temporalio::Error::CanceledError
      @canceled = true
      raise unless @swallow

      'done'
    end

    def wait_started
      @started.pop
    end
  end

  def test_cancellation_simple
    act = CancellationActivity.new
    execute_activity(
      act,
      cancel_on_signal: 'cancel-activity',
      wait_for_cancellation: true,
      heartbeat_timeout: 0.8
    ) do |handle|
      # Wait for it to start
      act.wait_started
      # Send activity cancel
      handle.signal('cancel-activity')
      # Wait for completion
      error = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_kind_of Temporalio::Error::CanceledError, error.cause
      # Confirm thrown in activity
      assert act.canceled
    end
  end

  def test_cancellation_swallowed
    act = CancellationActivity.new(swallow: true)
    execute_activity(
      act,
      cancel_on_signal: 'cancel-activity',
      wait_for_cancellation: true,
      heartbeat_timeout: 0.8
    ) do |handle|
      # Wait for it to start
      act.wait_started
      # Send activity cancel
      handle.signal('cancel-activity')
      # Wait for completion
      assert_equal 'done', handle.result
      # Confirm thrown in activity
      assert act.canceled
    end
  end

  class HeartbeatDetailsActivity < Temporalio::Activity::Definition
    def execute
      # First attempt sends a heartbeat with details and fails,
      # next attempt just returns the first attempt's details
      if Temporalio::Activity::Context.current.info.attempt == 1
        Temporalio::Activity::Context.current.heartbeat('detail1', 'detail2')
        raise 'Intentional error'
      else
        "details: #{Temporalio::Activity::Context.current.info.heartbeat_details}"
      end
    end
  end

  def test_heartbeat_details
    assert_equal 'details: ["detail1", "detail2"]',
                 execute_activity(HeartbeatDetailsActivity, retry_max_attempts: 2, heartbeat_timeout: 0.8)
  end

  class ShieldingActivity < Temporalio::Activity::Definition
    attr_reader :canceled, :levels_reached

    def initialize
      @waiting = Queue.new
      @canceled = false
      @levels_reached = 0
    end

    def execute
      # Do an outer shield and an inner shield and confirm not canceled until
      # after
      Temporalio::Activity::Context.current.cancellation.shield do
        Temporalio::Activity::Context.current.cancellation.shield do
          @waiting.push(nil)
          # Heartbeat every 50ms waiting for cancel
          until Temporalio::Activity::Context.current.cancellation.pending_canceled?
            sleep(0.05)
            Temporalio::Activity::Context.current.heartbeat
          end
          @levels_reached += 1
        end
        @levels_reached += 1
      end
    rescue Temporalio::Error::CanceledError
      @canceled = true
      raise
    end

    def wait_until_waiting
      @waiting.pop
    end
  end

  def test_activity_shielding
    act = ShieldingActivity.new
    execute_activity(
      act,
      cancel_on_signal: 'cancel-activity',
      wait_for_cancellation: true,
      heartbeat_timeout: 0.8
    ) do |handle|
      # Wait for it to be waiting
      act.wait_until_waiting
      # Send activity cancel
      handle.signal('cancel-activity')
      # Wait for completion
      error = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_kind_of Temporalio::Error::CanceledError, error.cause
      # Confirm thrown in activity but the proper levels reached
      assert act.canceled
      assert_equal 2, act.levels_reached
    end
  end

  class NoRaiseCancellationActivity < Temporalio::Activity::Definition
    activity_cancel_raise false
    attr_reader :canceled

    def initialize
      @started = Queue.new
    end

    def execute
      @started.push(nil)
      # Heartbeat until cancellation and then heartbeat a few more
      # ensuring we're not cancelling
      until Temporalio::Activity::Context.current.cancellation.canceled?
        sleep(0.05)
        Temporalio::Activity::Context.current.heartbeat
      end
      5.times do
        sleep(0.05)
        Temporalio::Activity::Context.current.heartbeat
      end
      'got canceled'
    end

    def wait_started
      @started.pop
    end
  end

  def test_no_raise_cancellation
    act = NoRaiseCancellationActivity.new
    execute_activity(
      act,
      cancel_on_signal: 'cancel-activity',
      wait_for_cancellation: true,
      heartbeat_timeout: 0.8
    ) do |handle|
      # Wait for it to start
      act.wait_started
      # Send activity cancel
      handle.signal('cancel-activity')
      # Wait for completion
      assert_equal 'got canceled', handle.result
    end
  end

  class WorkerShutdownActivity < Temporalio::Activity::Definition
    attr_reader :canceled

    def initialize
      @started = Queue.new
      @cancel_received = Queue.new
      @reraise_cancel = Queue.new
    end

    def execute
      @started.push(nil)
      # Heartbeat every 50ms
      loop do
        sleep(0.05)
        Temporalio::Activity::Context.current.heartbeat
      end
    rescue Temporalio::Error::CanceledError
      raise 'Not canceled' unless Temporalio::Activity::Context.current.worker_shutdown_cancellation.canceled?

      @cancel_received.push(nil)
      @reraise_cancel.pop
      raise
    end

    def wait_started
      @started.pop
    end

    def wait_cancel_received
      @cancel_received.pop
    end

    def reraise_cancel
      @reraise_cancel.push(nil)
    end
  end

  def test_worker_shutdown
    act = WorkerShutdownActivity.new
    # Start the activity, then cancel worker but let block complete
    worker_cancel, worker_cancel_proc = Temporalio::Cancellation.new
    workflow_handle = execute_activity(
      act,
      wait_for_cancellation: true,
      cancellation: worker_cancel,
      raise_in_block_on_shutdown: false
    ) do |handle|
      # Wait for it to be started
      act.wait_started
      # Do worker cancellation
      worker_cancel_proc.call
      act.wait_cancel_received
      act.reraise_cancel
      # Wait for workflow result
      assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      handle
    end

    # Check that cancel was due to worker shutdown
    error = assert_raises(Temporalio::Error::WorkflowFailedError) { workflow_handle.result }
    assert_kind_of Temporalio::Error::ActivityError, error.cause
    assert_kind_of Temporalio::Error::ApplicationError, error.cause.cause
    assert_equal 'WorkerShutdown', error.cause.cause.type
  end

  class AsyncCompletionActivity < Temporalio::Activity::Definition
    def initialize
      @task_token = Queue.new
    end

    def execute
      @task_token.push(Temporalio::Activity::Context.current.info.task_token)
      raise Temporalio::Activity::CompleteAsyncError
    end

    def wait_task_token
      @task_token.pop
    end
  end

  def test_async_completion_success
    act = AsyncCompletionActivity.new
    execute_activity(act) do |handle|
      # Wait for token
      task_token = act.wait_task_token

      # Send completion and confirm result
      env.client.async_activity_handle(task_token).complete('some result')
      assert_equal 'some result', handle.result
    end
  end

  def test_async_completion_heartbeat_and_fail
    act = AsyncCompletionActivity.new
    execute_activity(act) do |handle|
      # Wait for token
      task_token = act.wait_task_token

      # Send heartbeat and confirm details accurate
      env.client.async_activity_handle(task_token).heartbeat('foo', 'bar')
      assert_equal %w[foo bar],
                   env.client.data_converter.from_payloads(
                     handle.describe.raw_description.pending_activities.first.heartbeat_details
                   )

      # Send failure and confirm accurate
      env.client.async_activity_handle(task_token).fail(RuntimeError.new('Oh no'))
      error = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_kind_of Temporalio::Error::ActivityError, error.cause
      assert_kind_of Temporalio::Error::ApplicationError, error.cause.cause
      assert_equal 'Oh no', error.cause.cause.message
    end
  end

  def test_async_completion_cancel
    act = AsyncCompletionActivity.new
    execute_activity(act, wait_for_cancellation: true) do |handle|
      # Wait for token
      task_token = act.wait_task_token

      # Cancel workflow and confirm activity wants to be canceled
      handle.cancel
      assert_eventually do
        assert_raises(Temporalio::Error::AsyncActivityCanceledError) do
          env.client.async_activity_handle(task_token).heartbeat
        end
      end

      # Send cancel and confirm canceled
      env.client.async_activity_handle(task_token).report_cancellation
      error = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_kind_of Temporalio::Error::CanceledError, error.cause
    end
  end

  def test_async_completion_timeout
    act = AsyncCompletionActivity.new
    execute_activity(act, start_to_close_timeout: 0.5, wait_for_cancellation: true) do
      # Wait for token
      task_token = act.wait_task_token

      # Wait for activity to show not-found
      assert_eventually do
        error = assert_raises(Temporalio::Error::RPCError) do
          env.client.async_activity_handle(task_token).heartbeat
        end
        assert_equal Temporalio::Error::RPCError::Code::NOT_FOUND, error.code
      end
    end
  end

  class CustomExecutor < Temporalio::Worker::ActivityExecutor
    def execute_activity(_defn, &block)
      Thread.new do
        Thread.current[:some_local_val] = 'foo'
        block.call # steep:ignore
      end
    end

    def activity_context
      Thread.current[:temporal_activity_context]
    end

    def set_activity_context(_defn, context)
      Thread.current[:temporal_activity_context] = context
    end
  end

  class CustomExecutorActivity < Temporalio::Activity::Definition
    activity_executor :my_executor

    def execute
      "local val: #{Thread.current[:some_local_val]}"
    end
  end

  def test_custom_executor
    assert_equal 'local val: foo',
                 execute_activity(CustomExecutorActivity, activity_executors: { my_executor: CustomExecutor.new })
  end

  class ConcurrentActivity < Temporalio::Activity::Definition
    def initialize
      @started = Queue.new
      @continue = Queue.new
    end

    def execute(num)
      @started.push(nil)
      @continue.pop
      "done: #{num}"
    end

    def wait_started
      @started.pop
    end

    def continue
      @continue.push(nil)
    end
  end

  class ConcurrentFiberActivity < ConcurrentActivity
    activity_name 'ConcurrentActivity' # steep:ignore
    activity_executor :fiber # steep:ignore
  end

  def assert_multi_worker_activities(activities)
    workers = activities.each_with_index.map do |activity, index|
      Temporalio::Worker.new(
        client: env.client,
        task_queue: "tq-#{index}-#{SecureRandom.uuid}",
        activities: [activity],
        build_id: 'ignore'
      )
    end
    Temporalio::Worker.run_all(*workers) do
      env.with_kitchen_sink_worker do |kitchen_sink_task_queue|
        # Start workflow w/ concurrent activities
        handle = env.client.start_workflow(
          'kitchen_sink',
          { actions: [{
            concurrent: workers.each_with_index.map do |worker, index|
              {
                execute_activity: {
                  name: 'ConcurrentActivity',
                  task_queue: worker.task_queue,
                  args: [index]
                }
              }
            end
          }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue: kitchen_sink_task_queue
        )
        # Wait for all to be started
        activities.each(&:wait_started)
        # Continue all
        activities.each(&:continue)
        # Confirm result
        assert_equal activities.size.times.map { |i| "done: #{i}" }, handle.result
      end
    end
  end

  def test_concurrent_multi_worker_threaded_activities
    assert_multi_worker_activities(50.times.map { ConcurrentActivity.new })
  end

  def test_concurrent_multi_worker_fiber_activities
    skip 'Must be fiber-based worker to do fiber-based activities' if Fiber.current_scheduler.nil?
    assert_multi_worker_activities(50.times.map { ConcurrentFiberActivity.new })
  end

  def assert_single_worker_activities(activity, count)
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      activities: [activity]
    )
    worker.run do
      env.with_kitchen_sink_worker do |kitchen_sink_task_queue|
        handle = env.client.start_workflow(
          'kitchen_sink',
          { actions: [{
            concurrent: count.times.map do |index|
              {
                execute_activity: {
                  name: 'ConcurrentActivity',
                  task_queue: worker.task_queue,
                  args: [index]
                }
              }
            end
          }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue: kitchen_sink_task_queue
        )
        # Wait for all to be started
        count.times.each { activity.wait_started }
        # Continue all
        count.times.each { activity.continue } # rubocop:disable Style/CombinableLoops
        # Confirm result
        assert_equal count.times.map { |i| "done: #{i}" }, handle.result
      end
    end
  end

  def test_concurrent_single_worker_threaded_activities
    assert_single_worker_activities(ConcurrentActivity.new, 50)
  end

  def test_concurrent_single_worker_fiber_activities
    skip 'Must be fiber-based worker to do fiber-based activities' if Fiber.current_scheduler.nil?
    assert_single_worker_activities(ConcurrentFiberActivity.new, 50)
  end

  class TrackCallsInterceptor
    include Temporalio::Worker::Interceptor::Activity
    # Also include client interceptor so we can test worker interceptors at a
    # client level
    include Temporalio::Client::Interceptor

    attr_accessor :calls

    def initialize
      @calls = []
    end

    def intercept_activity(next_interceptor)
      Inbound.new(self, next_interceptor)
    end

    class Inbound < Temporalio::Worker::Interceptor::Activity::Inbound
      def initialize(root, next_interceptor)
        super(next_interceptor)
        @root = root
      end

      def init(outbound)
        @root.calls.push(['activity_init', Temporalio::Activity::Context.current.info.activity_type])
        super(Outbound.new(@root, outbound))
      end

      def execute(input)
        @root.calls.push(['activity_execute', input])
        super
      end
    end

    class Outbound < Temporalio::Worker::Interceptor::Activity::Outbound
      def initialize(root, next_interceptor)
        super(next_interceptor)
        @root = root
      end

      def heartbeat(input)
        @root.calls.push(['activity_heartbeat', input])
        super
      end
    end
  end

  class InterceptorActivity < Temporalio::Activity::Definition
    def execute(name)
      Temporalio::Activity::Context.current.heartbeat('heartbeat-val')
      "Hello, #{name}!"
    end
  end

  def test_interceptor
    interceptor = TrackCallsInterceptor.new
    assert_equal 'Hello, Temporal!', execute_activity(InterceptorActivity, 'Temporal', interceptors: [interceptor])
    assert_equal 'activity_init', interceptor.calls[0].first
    assert_equal 'InterceptorActivity', interceptor.calls[0][1]
    assert_equal 'activity_execute', interceptor.calls[1].first
    assert_equal ['Temporal'], interceptor.calls[1][1].args
    assert_equal 'activity_heartbeat', interceptor.calls[2].first
    assert_equal ['heartbeat-val'], interceptor.calls[2][1].details
  end

  def test_interceptor_from_client
    interceptor = TrackCallsInterceptor.new
    # Create new client with the interceptor set
    new_options = env.client.options.with(interceptors: [interceptor])
    new_client = Temporalio::Client.new(**new_options.to_h) # steep:ignore
    assert_equal 'Hello, Temporal!', execute_activity(InterceptorActivity, 'Temporal', client: new_client)
    assert_equal 'activity_init', interceptor.calls[0].first
    assert_equal 'InterceptorActivity', interceptor.calls[0][1]
    assert_equal 'activity_execute', interceptor.calls[1].first
    assert_equal ['Temporal'], interceptor.calls[1][1].args
    assert_equal 'activity_heartbeat', interceptor.calls[2].first
    assert_equal ['heartbeat-val'], interceptor.calls[2][1].details
  end

  class DynamicActivity < Temporalio::Activity::Definition
    activity_dynamic

    def execute(*args)
      "Activity #{Temporalio::Activity::Context.current.info.activity_type} called with #{args}"
    end
  end

  def test_dynamic_activity
    assert_equal 'Activity does-not-exist called with ["arg1", 123]',
                 execute_activity(DynamicActivity, 'arg1', 123, override_name: 'does-not-exist')
  end

  class DynamicActivityRawArgs < Temporalio::Activity::Definition
    activity_dynamic
    activity_raw_args

    def execute(*args)
      metadata_encodings, decoded_args = args.map do |arg|
        raise 'Bad type' unless arg.is_a?(Temporalio::Converters::RawValue)

        [arg.payload.metadata['encoding'],
         Temporalio::Activity::Context.current.payload_converter.from_payload(arg.payload)]
      end.transpose
      "Activity #{Temporalio::Activity::Context.current.info.activity_type} called with " \
        "#{decoded_args} that have encodings #{metadata_encodings}"
    end
  end

  def test_dynamic_activity_raw_args
    assert_equal 'Activity does-not-exist called with ' \
                 '["arg1", nil, 123] that have encodings ["json/plain", "binary/null", "json/plain"]',
                 execute_activity(DynamicActivityRawArgs, 'arg1', nil, 123, override_name: 'does-not-exist')
  end

  class ContextInstanceInterceptor
    include Temporalio::Worker::Interceptor::Activity

    def intercept_activity(next_interceptor)
      Inbound.new(next_interceptor)
    end

    class Inbound < Temporalio::Worker::Interceptor::Activity::Inbound
      def init(outbound)
        Temporalio::Activity::Context.current.instance.events&.<< 'interceptor-init' # steep:ignore
        super
      end

      def execute(input)
        Temporalio::Activity::Context.current.instance.events&.<< 'interceptor-execute' # steep:ignore
        super
      end
    end
  end

  class ContextInstanceActivity < Temporalio::Activity::Definition
    def events
      @events ||= []
    end

    def execute
      events << 'execute' # steep:ignore
    end
  end

  def test_context_instance
    # Instance-per-attempt (twice)
    assert_equal %w[interceptor-init interceptor-execute execute],
                 execute_activity(ContextInstanceActivity, interceptors: [ContextInstanceInterceptor.new])
    assert_equal %w[interceptor-init interceptor-execute execute],
                 execute_activity(ContextInstanceActivity, interceptors: [ContextInstanceInterceptor.new])
    # Shared instance
    shared_instance = ContextInstanceActivity.new
    assert_equal %w[interceptor-init interceptor-execute execute],
                 execute_activity(shared_instance, interceptors: [ContextInstanceInterceptor.new])
    assert_equal %w[interceptor-init interceptor-execute execute interceptor-init interceptor-execute execute],
                 execute_activity(shared_instance, interceptors: [ContextInstanceInterceptor.new])
  end

  class ClientAccessActivity < Temporalio::Activity::Definition
    def execute
      desc = Temporalio::Activity::Context.current.client.workflow_handle(
        Temporalio::Activity::Context.current.info.workflow_id
      ).describe
      desc.raw_description.pending_activities.first.activity_type.name
    end
  end

  def test_client_access
    assert_equal 'ClientAccessActivity', execute_activity(ClientAccessActivity)
  end

  class ReservedNameActivity < Temporalio::Activity::Definition
    activity_name '__temporal_activity'

    def execute; end
  end

  def test_reserved_name
    err = assert_raises { Temporalio::Activity::Definition::Info.from_activity(ReservedNameActivity) }
    assert_includes err.message, "'__temporal_activity' cannot start with '__temporal_'"
  end

  class KeywordArgumentActivity < Temporalio::Activity::Definition
    def execute(foo, bar: 'baz'); end
  end

  def test_keyword_arguments
    err = assert_raises { Temporalio::Activity::Definition::Info.from_activity(KeywordArgumentActivity) }
    assert_includes err.message, 'Activity execute cannot have keyword arguments'
    err = assert_raises { Temporalio::Activity::Definition::Info.from_activity(KeywordArgumentActivity.new) }
    assert_includes err.message, 'Activity execute cannot have keyword arguments'
  end

  # steep:ignore
  def execute_activity(
    activity,
    *args,
    retry_max_attempts: 1,
    logger: nil,
    heartbeat_timeout: nil,
    start_to_close_timeout: nil,
    override_name: nil,
    cancel_on_signal: nil,
    wait_for_cancellation: false,
    cancellation: nil,
    raise_in_block_on_shutdown: true,
    activity_executors: nil,
    interceptors: [],
    client: env.client
  )
    activity_defn = Temporalio::Activity::Definition::Info.from_activity(activity)
    extra_worker_args = {}
    extra_worker_args[:activity_executors] = activity_executors if activity_executors
    worker = Temporalio::Worker.new(
      client:,
      task_queue: "tq-#{SecureRandom.uuid}",
      activities: [activity],
      logger: logger || client.options.logger,
      interceptors:,
      **extra_worker_args
    )
    run_args = {}
    run_args[:cancellation] = cancellation unless cancellation.nil?
    run_args[:raise_in_block_on_shutdown] = nil unless raise_in_block_on_shutdown
    worker.run(**run_args) do
      env.with_kitchen_sink_worker do |kitchen_sink_task_queue|
        handle = client.start_workflow(
          'kitchen_sink',
          { actions: [{ execute_activity: {
            name: override_name || activity_defn.name,
            task_queue: worker.task_queue,
            args:,
            retry_max_attempts:,
            cancel_on_signal:,
            wait_for_cancellation:,
            heartbeat_timeout_ms: heartbeat_timeout ? (heartbeat_timeout * 1000).to_i : nil,
            start_to_close_timeout_ms: start_to_close_timeout ? (start_to_close_timeout * 1000).to_i : nil
          } }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue: kitchen_sink_task_queue
        )
        if block_given?
          yield handle, worker
        else
          handle.result
        end
      end
    end
  end
end
