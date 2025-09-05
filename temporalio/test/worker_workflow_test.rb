# frozen_string_literal: true

require 'base64_codec'
require 'gc_utils'
require 'net/http'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'
require 'timeout'

class WorkerWorkflowTest < Test
  class SimpleWorkflow < Temporalio::Workflow::Definition
    def execute(name)
      "Hello, #{name}!"
    end
  end

  def test_simple
    assert_equal 'Hello, Temporal!', execute_workflow(SimpleWorkflow, 'Temporal')
  end

  IGNORED_LOGGER = Logger.new($stdout) # rubocop:disable Layout/ClassStructure

  class IllegalCallsWorkflow < Temporalio::Workflow::Definition
    def execute(scenario)
      case scenario.to_sym
      when :argv
        ARGV
      when :date_new
        Date.new
      when :date_today
        Date.today
      when :env
        ENV.fetch('foo', nil)
      when :file_directory
        File.directory?('.')
      when :file_read
        File.read('Rakefile')
      when :http_get
        Net::HTTP.get('https://example.com')
      when :kernel_rand
        Kernel.rand
      when :random_new
        Random.new.rand
      when :thread_new
        Thread.new { 'wut' }.join
      when :time_new
        Time.new
      when :time_new_parse
        Time.new('2000-12-31 23:59:59.5')
      when :time_new_explicit
        Time.new(2000, 1, 2, 3, 4, 5)
      when :time_now
        Time.now
      when :time_iso8601
        Time.iso8601('2011-10-05T22:26:12-04:00')
      when :stdlib_logger_write
        IGNORED_LOGGER.info('test')
      when :workflow_logger_write
        Temporalio::Workflow.logger.info('test')
      when :sleep
        sleep(0.1)
      when :timeout
        Timeout.timeout(0.1) { 'test' }
      when :queue
        Queue.new
      when :sized_queue
        SizedQueue.new
      when :mutex
        Mutex.new
      when :condvar
        ConditionVariable.new
      when :monitor
        Monitor.new.synchronize { 'test' }
      else
        raise NotImplementedError
      end
    end
  end

  def test_illegal_calls
    exec = lambda do |scenario, method|
      execute_workflow(IllegalCallsWorkflow, scenario) do |handle|
        if method
          assert_eventually_task_fail(handle:, message_contains: "Cannot access #{method} from inside a workflow")
        else
          handle.result
        end
      end
    end

    exec.call(:argv, nil) # Cannot reasonably prevent
    exec.call(:date_new, 'Date initialize')
    exec.call(:date_today, 'Date today')
    exec.call(:env, nil) # Cannot reasonably prevent
    exec.call(:file_directory, 'File directory?')
    exec.call(:file_read, 'IO read')
    exec.call(:http_get, 'Net::HTTP get')
    exec.call(:kernel_rand, 'Kernel rand')
    exec.call(:random_new, 'Random::Base initialize')
    exec.call(:thread_new, 'Thread new')
    exec.call(:time_new, 'Time initialize')
    exec.call(:time_new_parse, nil) # This call is ok
    exec.call(:time_new_explicit, nil) # This call is ok
    exec.call(:time_now, 'Time now')
    exec.call(:time_iso8601, nil) # This call is ok
    exec.call(:stdlib_logger_write, 'Logger info')
    exec.call(:workflow_logger_write, nil) # This call is ok
    exec.call(:sleep, 'Kernel sleep')
    exec.call(:timeout, 'Timeout timeout')
    exec.call(:queue, 'Thread::Queue initialize')
    exec.call(:sized_queue, 'Thread::SizedQueue initialize')
    exec.call(:mutex, 'Thread::Mutex initialize')
    exec.call(:condvar, 'Thread::ConditionVariable initialize')
    exec.call(:monitor, 'Monitor synchronize')
  end

  class WorkflowInitWorkflow < Temporalio::Workflow::Definition
    workflow_init
    def initialize(arg1, arg2)
      @args = [arg1, arg2]
    end

    def execute(_ignore1, _ignore2)
      @args
    end
  end

  def test_workflow_init
    assert_equal ['foo', 123], execute_workflow(WorkflowInitWorkflow, 'foo', 123)
  end

  class RawValueWorkflow < Temporalio::Workflow::Definition
    workflow_raw_args

    workflow_init
    def initialize(arg1, arg2)
      raise 'Expected raw' unless arg1.is_a?(Temporalio::Converters::RawValue)
      raise 'Expected raw' unless arg2.is_a?(Temporalio::Converters::RawValue)
    end

    def execute(arg1, arg2)
      raise 'Expected raw' unless arg1.is_a?(Temporalio::Converters::RawValue)
      raise 'Bad value' unless Temporalio::Workflow.payload_converter.from_payload(arg1.payload) == 'foo'
      raise 'Expected raw' unless arg2.is_a?(Temporalio::Converters::RawValue)
      raise 'Bad value' unless Temporalio::Workflow.payload_converter.from_payload(arg2.payload) == 123

      Temporalio::Converters::RawValue.new(
        Temporalio::Api::Common::V1::Payload.new(
          metadata: { 'encoding' => 'json/plain' },
          data: '{"foo": "bar"}'.b
        )
      )
    end
  end

  def test_raw_value
    assert_equal({ 'foo' => 'bar' }, execute_workflow(RawValueWorkflow, 'foo', 123))
  end

  class ArgCountWorkflow < Temporalio::Workflow::Definition
    def execute(arg1, arg2)
      [arg1, arg2]
    end
  end

  def test_arg_count
    # Extra arguments are allowed and just discarded, too few are not allowed
    execute_workflow(ArgCountWorkflow) do |handle|
      assert_eventually_task_fail(
        handle:,
        message_contains: 'wrong number of required arguments for execute (given 0, expected 2)'
      )
    end
    assert_equal %w[one two], execute_workflow(ArgCountWorkflow, 'one', 'two')
    assert_equal %w[three four], execute_workflow(ArgCountWorkflow, 'three', 'four', 'five')
  end

  class InfoWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.info.to_h.tap do |h|
        h['parent'] = Temporalio::Workflow.info.parent.to_h if Temporalio::Workflow.info.parent
        h['root'] = Temporalio::Workflow.info.root.to_h if Temporalio::Workflow.info.root
        h['start_time'] = Temporalio::Workflow.info.start_time.to_s
      end
    end
  end

  class InfoFromChildWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.execute_child_workflow(InfoWorkflow)
    end
  end

  def test_info
    # Normal info
    execute_workflow(InfoWorkflow) do |handle, worker|
      info = handle.result #: Hash[String, untyped]
      desc = handle.describe
      assert_equal 1, info['attempt']
      assert_nil info.fetch('continued_run_id')
      assert_nil info.fetch('cron_schedule')
      assert_nil info.fetch('execution_timeout')
      assert_nil info.fetch('last_failure')
      assert_nil info.fetch('last_result')
      assert_equal env.client.namespace, info['namespace']
      assert_nil info.fetch('parent')
      assert_nil info.fetch('retry_policy')
      assert_nil info.fetch('root')
      assert_equal handle.result_run_id, info['run_id']
      assert_nil info.fetch('run_timeout')
      assert_equal desc.start_time.to_s, info['start_time']
      assert_equal worker.task_queue, info['task_queue']
      assert_equal 10.0, info['task_timeout']
      assert_equal handle.id, info['workflow_id']
      assert_equal 'InfoWorkflow', info['workflow_type']
    end
    # Child info
    execute_workflow(InfoFromChildWorkflow, more_workflows: [InfoWorkflow]) do |handle|
      info = handle.result #: Hash[String, untyped]
      assert_equal env.client.namespace, info['parent']['namespace']
      assert_equal handle.id, info['parent']['workflow_id']
      assert_equal handle.result_run_id, info['parent']['run_id']
      assert_equal handle.id, info['root']['workflow_id']
      assert_equal handle.result_run_id, info['root']['run_id']
    end
  end

  class HistoryInfoWorkflow < Temporalio::Workflow::Definition
    def execute
      # Start 30 10ms timers and wait on them all
      Temporalio::Workflow::Future.all_of(
        *30.times.map { Temporalio::Workflow::Future.new { Temporalio::Workflow.sleep(0.1) } }
      ).wait

      [
        Temporalio::Workflow.continue_as_new_suggested,
        Temporalio::Workflow.current_history_length,
        Temporalio::Workflow.current_history_size
      ]
    end
  end

  def test_history_info
    can_suggested, hist_len, hist_size = execute_workflow(HistoryInfoWorkflow) #: [bool, Integer, Integer]
    refute can_suggested
    assert hist_len > 60
    assert hist_size > 1500
  end

  class WaitConditionWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :waiting

    def execute(scenario)
      case scenario.to_sym
      when :stages
        @stages = ['one']
        Temporalio::Workflow::Future.new do
          Temporalio::Workflow.wait_condition { @stages.last != 'one' }
          raise 'Invalid stage' unless @stages.last == 'two'

          @stages << 'three'
        end
        Temporalio::Workflow::Future.new do
          Temporalio::Workflow.wait_condition { !@stages.empty? }
          raise 'Invalid stage' unless @stages.last == 'one'

          @stages << 'two'
        end
        Temporalio::Workflow::Future.new do
          Temporalio::Workflow.wait_condition { !@stages.empty? }
          raise 'Invalid stage' unless @stages.last == 'three'

          @stages << 'four'
        end
        Temporalio::Workflow.wait_condition { @stages.last == 'four' }
        @stages
      when :workflow_cancel
        @waiting = true
        Temporalio::Workflow.wait_condition { false }
      when :timeout
        Temporalio::Workflow.timeout(0.1) do
          Temporalio::Workflow.wait_condition { false }
        end
      when :manual_cancel
        my_cancel, my_cancel_proc = Temporalio::Cancellation.new
        Temporalio::Workflow::Future.new do
          Temporalio::Workflow.sleep(0.1)
          my_cancel_proc.call(reason: 'my cancel reason')
        end
        Temporalio::Workflow.wait_condition(cancellation: my_cancel) { false }
      when :manual_cancel_before_wait
        my_cancel, my_cancel_proc = Temporalio::Cancellation.new
        my_cancel_proc.call(reason: 'my cancel reason')
        Temporalio::Workflow.wait_condition(cancellation: my_cancel) { false }
      else
        raise NotImplementedError
      end
    end
  end

  def test_wait_condition
    assert_equal %w[one two three four], execute_workflow(WaitConditionWorkflow, :stages)

    execute_workflow(WaitConditionWorkflow, :workflow_cancel) do |handle|
      assert_eventually { assert handle.query(WaitConditionWorkflow.waiting) }
      handle.cancel
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_equal 'Workflow execution canceled', err.message
      assert_instance_of Temporalio::Error::CanceledError, err.cause
    end

    err = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_workflow(WaitConditionWorkflow, :timeout) }
    assert_equal 'execution expired', err.cause.message

    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(WaitConditionWorkflow, :manual_cancel)
    end
    assert_equal 'Workflow execution failed', err.message
    assert_instance_of Temporalio::Error::CanceledError, err.cause
    assert_equal 'my cancel reason', err.cause.message

    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(WaitConditionWorkflow, :manual_cancel_before_wait)
    end
    assert_equal 'Workflow execution failed', err.message
    assert_instance_of Temporalio::Error::CanceledError, err.cause
    assert_equal 'my cancel reason', err.cause.message
  end

  class TimerWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :waiting

    def execute(scenario)
      case scenario.to_sym
      when :sleep_workflow
        Temporalio::Workflow.sleep(0.12, summary: 'my summary')
      when :sleep_workflow_cancel
        Temporalio::Workflow.sleep(1000)
      when :sleep_explicit_cancel
        my_cancel, my_cancel_proc = Temporalio::Cancellation.new
        Temporalio::Workflow::Future.new do
          Temporalio::Workflow.sleep(0.1)
          my_cancel_proc.call(reason: 'my cancel reason')
        end
        Temporalio::Workflow.sleep(1000, cancellation: my_cancel)
      when :sleep_cancel_before_start
        my_cancel, my_cancel_proc = Temporalio::Cancellation.new
        my_cancel_proc.call(reason: 'my cancel reason')
        Temporalio::Workflow.sleep(1000, cancellation: my_cancel)
      when :timeout_workflow
        Temporalio::Workflow.timeout(0.17) do
          Temporalio::Workflow.wait_condition { false }
        end
      when :timeout_custom_info
        Temporalio::Workflow.timeout(0.18, Temporalio::Error::ApplicationError, 'some message') do
          Temporalio::Workflow.wait_condition { false }
        end
      when :timeout_infinite
        @waiting = true
        Temporalio::Workflow.timeout(nil) do
          Temporalio::Workflow.wait_condition { @interrupt }
        end
      when :timeout_negative
        Temporalio::Workflow.timeout(-1) do
          Temporalio::Workflow.wait_condition { false }
        end
      when :timeout_workflow_cancel
        Temporalio::Workflow.timeout(1000) do
          Temporalio::Workflow.wait_condition { false }
        end
      when :timeout_not_reached
        Temporalio::Workflow.timeout(1000) do
          Temporalio::Workflow.wait_condition { @return_value }
        end
        @waiting = true
        Temporalio::Workflow.wait_condition { @interrupt }
        @return_value
      else
        raise NotImplementedError
      end
    end

    workflow_signal
    def interrupt
      @interrupt = true
    end

    workflow_signal
    def return_value(value)
      @return_value = value
    end
  end

  def test_timer
    event = execute_workflow(TimerWorkflow, :sleep_workflow) do |handle|
      handle.result
      handle.fetch_history_events.find(&:timer_started_event_attributes)
    end
    assert_equal 0.12, event.timer_started_event_attributes.start_to_fire_timeout.to_f
    # TODO(cretz): Assert summary

    execute_workflow(TimerWorkflow, :sleep_workflow_cancel) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:timer_started_event_attributes) }
      handle.cancel
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_instance_of Temporalio::Error::CanceledError, err.cause
    end

    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(TimerWorkflow, :sleep_explicit_cancel)
    end
    assert_equal 'Workflow execution failed', err.message
    assert_instance_of Temporalio::Error::CanceledError, err.cause
    assert_equal 'my cancel reason', err.cause.message

    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(TimerWorkflow, :sleep_cancel_before_start)
    end
    assert_equal 'Workflow execution failed', err.message
    assert_instance_of Temporalio::Error::CanceledError, err.cause
    assert_equal 'my cancel reason', err.cause.message

    err = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_workflow(TimerWorkflow, :timeout_workflow) }
    assert_instance_of Temporalio::Error::ApplicationError, err.cause
    assert_equal 'execution expired', err.cause.message
    assert_equal 'Error', err.cause.type

    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(TimerWorkflow, :timeout_custom_info)
    end
    assert_instance_of Temporalio::Error::ApplicationError, err.cause
    assert_equal 'some message', err.cause.message
    assert_nil err.cause.type

    execute_workflow(TimerWorkflow, :timeout_infinite) do |handle|
      assert_eventually { assert handle.query(TimerWorkflow.waiting) }
      handle.signal(TimerWorkflow.interrupt)
      handle.result
      refute handle.fetch_history_events.any?(&:timer_started_event_attributes)
    end

    execute_workflow(TimerWorkflow, :timeout_negative) do |handle|
      assert_eventually_task_fail(handle:, message_contains: 'Sleep duration cannot be less than 0')
    end

    execute_workflow(TimerWorkflow, :timeout_workflow_cancel) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:timer_started_event_attributes) }
      handle.cancel
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_instance_of Temporalio::Error::CanceledError, err.cause
    end

    execute_workflow(TimerWorkflow, :timeout_not_reached) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:timer_started_event_attributes) }
      handle.signal(TimerWorkflow.return_value, 'some value')
      assert_eventually { assert handle.query(TimerWorkflow.waiting) }
      assert_eventually { assert handle.fetch_history_events.any?(&:timer_canceled_event_attributes) }
      handle.signal(TimerWorkflow.interrupt)
      assert_equal 'some value', handle.result
    end
  end

  class SearchAttributeMemoWorkflow < Temporalio::Workflow::Definition
    def execute(scenario)
      case scenario.to_sym
      when :search_attributes
        # Collect original, upsert (update one, delete another), collect updated
        orig = Temporalio::Workflow.search_attributes.to_h.transform_keys(&:name)
        Temporalio::Workflow.upsert_search_attributes(
          Test::ATTR_KEY_TEXT.value_set('another-text'),
          Test::ATTR_KEY_KEYWORD.value_unset
        )
        updated = Temporalio::Workflow.search_attributes.to_h.transform_keys(&:name)
        { orig:, updated: }
      when :memo
        # Collect original, upsert (update one, delete another), collect updated
        orig = Temporalio::Workflow.memo.dup
        Temporalio::Workflow.upsert_memo({ key1: 'new-val1', key2: nil })
        updated = Temporalio::Workflow.memo.dup
        { orig:, updated: }
      else
        raise NotImplementedError
      end
    end
  end

  def test_search_attributes_memo
    env.ensure_common_search_attribute_keys

    execute_workflow(
      SearchAttributeMemoWorkflow,
      :search_attributes,
      search_attributes: Temporalio::SearchAttributes.new(
        { ATTR_KEY_TEXT => 'some-text', ATTR_KEY_KEYWORD => 'some-keyword', ATTR_KEY_INTEGER => 123 }
      )
    ) do |handle|
      result = handle.result #: Hash[String, untyped]

      # Check result attrs
      assert_equal 'some-text', result['orig'][ATTR_KEY_TEXT.name]
      assert_equal 'some-keyword', result['orig'][ATTR_KEY_KEYWORD.name]
      assert_equal 123, result['orig'][ATTR_KEY_INTEGER.name]
      assert_equal 'another-text', result['updated'][ATTR_KEY_TEXT.name]
      assert_nil result['updated'][ATTR_KEY_KEYWORD.name]
      assert_equal 123, result['updated'][ATTR_KEY_INTEGER.name]

      # Check describe
      desc = handle.describe
      attrs = desc.search_attributes || raise
      assert_equal 'another-text', attrs[ATTR_KEY_TEXT]
      assert_nil attrs[ATTR_KEY_KEYWORD]
      assert_equal 123, attrs[ATTR_KEY_INTEGER]
    end

    execute_workflow(
      SearchAttributeMemoWorkflow,
      :memo,
      memo: { key1: 'val1', key2: 'val2', key3: 'val3' }
    ) do |handle|
      result = handle.result #: Hash[String, untyped]

      # Check result attrs
      assert_equal({ 'key1' => 'val1', 'key2' => 'val2', 'key3' => 'val3' }, result['orig'])
      assert_equal({ 'key1' => 'new-val1', 'key3' => 'val3' }, result['updated'])

      # Check describe
      assert_equal({ 'key1' => 'new-val1', 'key3' => 'val3' }, handle.describe.memo)
    end
  end

  class ContinueAsNewWorkflow < Temporalio::Workflow::Definition
    def execute(past_run_ids)
      raise 'Incorrect memo' unless Temporalio::Workflow.memo['past_run_id_count'] == past_run_ids.size
      unless Temporalio::Workflow.info.retry_policy&.max_attempts == past_run_ids.size + 1000
        raise 'Incorrect retry policy'
      end

      # CAN until 5 run IDs, updating memo and retry policy on the way
      return past_run_ids if past_run_ids.size == 5

      past_run_ids << Temporalio::Workflow.info.continued_run_id if Temporalio::Workflow.info.continued_run_id
      raise Temporalio::Workflow::ContinueAsNewError.new(
        past_run_ids,
        memo: { past_run_id_count: past_run_ids.size },
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: past_run_ids.size + 1000)
      )
    end
  end

  def test_continue_as_new
    execute_workflow(
      ContinueAsNewWorkflow,
      [],
      # Set initial memo and retry policy, which we expect the workflow will update in CAN
      memo: { past_run_id_count: 0 },
      retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1000)
    ) do |handle|
      result = handle.result #: Array[String]
      assert_equal 5, result.size
      assert_equal handle.result_run_id, result.first
    end
  end

  class DeadlockWorkflow < Temporalio::Workflow::Definition
    def execute
      loop do
        # Do nothing
      end
    end
  end

  def test_deadlock
    # TODO(cretz): Do we need more tests? This attempts to interrupt the workflow via a raise on the thread, but do we
    # need to concern ourselves with what happens if that's accidentally swallowed?
    # TODO(cretz): Note that often mutexes and cond vars are not subject to Timeout.timeout which means they can not be
    # interrupted by deadlock detection
    # TODO(cretz): Note that a thread.join that does get deadlock detected may crash the VM on exit with a
    # "[BUG] pthread_mutex_lock: Invalid argument (EINVAL)"
    # TODO(cretz): Decrease deadlock detection timeout to make test faster? It is 4s now because shutdown waits on
    # second task.
    execute_workflow(DeadlockWorkflow) do |handle|
      assert_eventually_task_fail(handle:, message_contains: 'Potential deadlock detected')
    end
  end

  class StackTraceWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :expected_traces

    def initialize
      @expected_traces = []
    end

    def execute
      # Wait forever two coroutines deep
      Temporalio::Workflow::Future.new do
        Temporalio::Workflow::Future.new do
          @expected_traces << ["#{__FILE__}:#{__LINE__ + 1}"]
          Temporalio::Workflow.wait_condition { false }
        end
      end

      # Inside a coroutine and timeout, execute an activity forever
      Temporalio::Workflow::Future.new do
        Temporalio::Workflow.timeout(nil) do
          @expected_traces << ["#{__FILE__}:#{__LINE__ + 1}", "#{__FILE__}:#{__LINE__ - 1}"]
          Temporalio::Workflow.execute_activity('does-not-exist',
                                                task_queue: 'does-not-exist',
                                                start_to_close_timeout: 1000)
        end
      end

      # Wait forever inside a workflow timeout
      Temporalio::Workflow.timeout(nil) do
        @expected_traces << ["#{__FILE__}:#{__LINE__ + 1}", "#{__FILE__}:#{__LINE__ - 1}"]
        Temporalio::Workflow.wait_condition { false }
      end
    end

    workflow_signal
    def wait_signal
      added_trace = ["#{__FILE__}:#{__LINE__ + 2}"]
      @expected_traces << added_trace
      Temporalio::Workflow.wait_condition { @resume_waited_signal }
      @expected_traces.delete(added_trace)
    end

    workflow_update
    def wait_update
      do_recursive_thing(times_remaining: 5, lines: ["#{__FILE__}:#{__LINE__}"]) # steep:ignore
    end

    def do_recursive_thing(times_remaining:, lines:)
      unless times_remaining.zero?
        do_recursive_thing( # steep:ignore
          times_remaining: times_remaining - 1,
          lines: lines << "#{__FILE__}:#{__LINE__ - 2}"
        )
      end
      @expected_traces << (lines << "#{__FILE__}:#{__LINE__ + 1}")
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_signal
    def resume_waited_signal
      @resume_waited_signal = true
    end
  end

  def test_stack_trace
    execute_workflow(StackTraceWorkflow) do |handle|
      # Start a signal and an update
      handle.signal(StackTraceWorkflow.wait_signal)
      handle.start_update(StackTraceWorkflow.wait_update,
                          wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED)
      assert_expected_traces = lambda do
        actual_traces = handle.query('__stack_trace').split("\n\n").map do |lines| # steep:ignore
          # Trim off non-this-class things and ":in ..."
          lines.split("\n").select { |line| line.include?('worker_workflow_test') }.map do |line|
            line, = line.partition(':in')
            line
          end.sort
        end.sort
        expected_traces = handle.query(StackTraceWorkflow.expected_traces).map(&:sort).sort # steep:ignore
        assert_equal expected_traces, actual_traces
      end

      # Wait for there to be 5 expected traces and confirm proper trace
      assert_eventually { assert_equal 5, handle.query(StackTraceWorkflow.expected_traces).size } # steep:ignore
      assert_expected_traces.call

      # Now complete the waited handle and confirm again
      handle.signal(StackTraceWorkflow.resume_waited_signal)
      assert_equal 4, handle.query(StackTraceWorkflow.expected_traces).size # steep:ignore
      assert_expected_traces.call
    end
  end

  class TaskFailureError1 < StandardError; end
  class TaskFailureError2 < StandardError; end
  class TaskFailureError3 < StandardError; end
  class TaskFailureError4 < TaskFailureError3; end

  class TaskFailureWorkflow < Temporalio::Workflow::Definition
    workflow_failure_exception_type TaskFailureError2, TaskFailureError3

    def execute(arg)
      case arg
      when 1
        raise TaskFailureError1, 'one'
      when 2
        raise TaskFailureError2, 'two'
      when 3
        raise TaskFailureError3, 'three'
      when 4
        raise TaskFailureError4, 'four'
      when 'arg'
        raise ArgumentError, 'arg'
      else
        raise NotImplementedError
      end
    end
  end

  def test_task_failure
    # Normally just fails task
    execute_workflow(TaskFailureWorkflow, 1) do |handle|
      assert_eventually_task_fail(handle:, message_contains: 'one')
    end

    # Fails workflow when configured on worker
    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(TaskFailureWorkflow, 1, workflow_failure_exception_types: [TaskFailureError1])
    end
    assert_equal 'one', err.cause.message
    assert_equal 'TaskFailureError1', err.cause.type

    # Fails workflow when configured on workflow, including inherited
    err = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_workflow(TaskFailureWorkflow, 2) }
    assert_equal 'two', err.cause.message
    assert_equal 'TaskFailureError2', err.cause.type
    err = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_workflow(TaskFailureWorkflow, 4) }
    assert_equal 'four', err.cause.message
    assert_equal 'TaskFailureError4', err.cause.type

    # Also supports stdlib errors
    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(TaskFailureWorkflow, 'arg', workflow_failure_exception_types: [ArgumentError])
    end
    assert_equal 'arg', err.cause.message
    assert_equal 'ArgumentError', err.cause.type
  end

  class NonDeterminismErrorWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :waiting

    def execute
      # Do a timer only on non-replay
      Temporalio::Workflow.sleep(0.01) unless Temporalio::Workflow::Unsafe.replaying?
      Temporalio::Workflow.wait_condition { @finish }
    end

    workflow_signal
    def finish
      @finish = true
    end
  end

  class NonDeterminismErrorSpecificAsFailureWorkflow < NonDeterminismErrorWorkflow
    # @type module: Temporalio::Workflow::Definition.class

    workflow_failure_exception_type Temporalio::Workflow::NondeterminismError
  end

  class NonDeterminismErrorGenericAsFailureWorkflow < NonDeterminismErrorWorkflow
    workflow_failure_exception_type StandardError
  end

  def test_non_determinism_error
    # Task failure by default
    execute_workflow(NonDeterminismErrorWorkflow, max_cached_workflows: 0) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      handle.signal(NonDeterminismErrorWorkflow.finish)
      assert_eventually_task_fail(handle:, message_contains: 'Nondeterminism')
    end

    # Specifically set on worker turns to failure
    execute_workflow(NonDeterminismErrorWorkflow,
                     max_cached_workflows: 0,
                     workflow_failure_exception_types: [Temporalio::Workflow::NondeterminismError]) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      handle.signal(NonDeterminismErrorWorkflow.finish)
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_includes err.cause.message, 'Nondeterminism'
    end

    # Generically set on worker turns to failure
    execute_workflow(NonDeterminismErrorWorkflow,
                     max_cached_workflows: 0,
                     workflow_failure_exception_types: [StandardError]) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      handle.signal(NonDeterminismErrorWorkflow.finish)
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_includes err.cause.message, 'Nondeterminism'
    end

    # Specifically set on workflow turns to failure
    execute_workflow(NonDeterminismErrorSpecificAsFailureWorkflow, max_cached_workflows: 0) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      handle.signal(NonDeterminismErrorSpecificAsFailureWorkflow.finish)
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_includes err.cause.message, 'Nondeterminism'
    end

    # Generically set on workflow turns to failure
    execute_workflow(NonDeterminismErrorGenericAsFailureWorkflow, max_cached_workflows: 0) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      handle.signal(NonDeterminismErrorGenericAsFailureWorkflow.finish)
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_includes err.cause.message, 'Nondeterminism'
    end
  end

  class LoggerWorkflow < Temporalio::Workflow::Definition
    def initialize
      @bad_logger = Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled { Logger.new($stdout) }
    end

    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_update
    def update
      Temporalio::Workflow.logger.info('some-log-1')
      Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled { @bad_logger.info('some-log-2') }
      Temporalio::Workflow.sleep(0.01)
    end

    workflow_signal
    def cause_task_failure
      raise 'Some failure'
    end
  end

  def test_logger
    # Have to make a new logger so stdout after capturing here
    out, = safe_capture_io do
      execute_workflow(LoggerWorkflow, max_cached_workflows: 0, logger: Logger.new($stdout)) do |handle|
        handle.execute_update(LoggerWorkflow.update)
        # Send signal which causes replay when cache disabled
        handle.signal(:some_signal)
      end
    end
    lines = out.split("\n")

    # Confirm there is only one good line and it has contextual info
    good_lines = lines.select { |l| l.include?('some-log-1') }
    assert_equal 1, good_lines.size
    assert_includes good_lines.first, 'workflow_type'
    assert_includes good_lines.first, '"LoggerWorkflow"'

    # Confirm there are two bad lines, and they don't have contextual info
    bad_lines = lines.select { |l| l.include?('some-log-2') }
    assert bad_lines.size >= 2
    refute_includes bad_lines.first, '"LoggerWorkflow"'

    # Confirm task failure logs
    out, = safe_capture_io do
      execute_workflow(LoggerWorkflow, logger: Logger.new($stdout)) do |handle|
        handle.signal(LoggerWorkflow.cause_task_failure)
        assert_eventually_task_fail(handle:)
      end
    end
    lines = out.split("\n").select { |l| l.include?('workflow_type') && l.include?('"LoggerWorkflow"') }
    assert(lines.any? { |l| l.include?('Failed activation') })
    assert(lines.any? { |l| l.include?('Some failure') })
  end

  class CancelWorkflow < Temporalio::Workflow::Definition
    def execute(scenario)
      case scenario.to_sym
      when :swallow
        begin
          Temporalio::Workflow.wait_condition { false }
        rescue Temporalio::Error::CanceledError
          'done'
        end
      else
        raise NotImplementedError
      end
    end
  end

  def test_cancel
    execute_workflow(CancelWorkflow, :swallow) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      handle.cancel
      assert_equal 'done', handle.result
    end
  end

  class FutureWorkflowError < StandardError; end

  class FutureWorkflow < Temporalio::Workflow::Definition
    def execute(scenario)
      case scenario.to_sym
      when :any_of
        # Basic any of
        result = Temporalio::Workflow::Future.any_of(
          Temporalio::Workflow::Future.new { Temporalio::Workflow.sleep(0.01) },
          Temporalio::Workflow::Future.new { 'done' }
        ).wait
        raise unless result == 'done'

        # Any of with exception
        begin
          Temporalio::Workflow::Future.any_of(
            Temporalio::Workflow::Future.new { Temporalio::Workflow.sleep(0.01) },
            Temporalio::Workflow::Future.new { raise FutureWorkflowError }
          ).wait
          raise
        rescue FutureWorkflowError
          # Do nothing
        end

        # Try any of
        result = Temporalio::Workflow::Future.try_any_of(
          Temporalio::Workflow::Future.new { Temporalio::Workflow.sleep(0.01) },
          Temporalio::Workflow::Future.new { 'done' }
        ).wait.wait
        raise unless result == 'done'

        # Try any of with exception
        try_any_of = Temporalio::Workflow::Future.try_any_of(
          Temporalio::Workflow::Future.new { Temporalio::Workflow.sleep(0.01) },
          Temporalio::Workflow::Future.new { raise FutureWorkflowError }
        ).wait
        begin
          try_any_of.wait
          raise
        rescue FutureWorkflowError
          # Do nothing
        end
      when :all_of
        # Basic all of
        fut1 = Temporalio::Workflow::Future.new { 'done1' }
        fut2 = Temporalio::Workflow::Future.new { 'done2' }
        Temporalio::Workflow::Future.all_of(fut1, fut2).wait
        raise unless fut1.done? && fut2.done?

        # All of with exception
        fut1 = Temporalio::Workflow::Future.new { 'done1' }
        fut2 = Temporalio::Workflow::Future.new { raise FutureWorkflowError }
        begin
          Temporalio::Workflow::Future.all_of(fut1, fut2).wait
          raise
        rescue FutureWorkflowError
          # Do nothing
        end

        # Try all of
        fut1 = Temporalio::Workflow::Future.new { 'done1' }
        fut2 = Temporalio::Workflow::Future.new { 'done2' }
        Temporalio::Workflow::Future.try_all_of(fut1, fut2).wait
        raise unless fut1.done? && fut2.done?

        # Try all of with exception
        fut1 = Temporalio::Workflow::Future.new { 'done1' }
        fut2 = Temporalio::Workflow::Future.new { raise FutureWorkflowError }
        Temporalio::Workflow::Future.try_all_of(fut1, fut2).wait
        begin
          fut2.wait
          raise
        rescue FutureWorkflowError
          # Do nothing
        end
      when :set_result
        fut = Temporalio::Workflow::Future.new
        fut.result = 'some result'
        raise unless fut.wait == 'some result'
      when :set_failure
        fut = Temporalio::Workflow::Future.new
        fut.failure = FutureWorkflowError.new
        begin
          fut.wait
          raise
        rescue FutureWorkflowError
          # Do nothing
        end
        raise unless fut.wait_no_raise.nil?
        raise unless fut.failure.is_a?(FutureWorkflowError)
      when :cancel
        # Cancel does not affect future
        fut = Temporalio::Workflow::Future.new do
          Temporalio::Workflow.wait_condition { false }
        rescue Temporalio::Error::CanceledError
          'done'
        end
        fut.wait
      else
        raise NotImplementedError
      end
    end
  end

  def test_future
    execute_workflow(FutureWorkflow, :any_of)
    execute_workflow(FutureWorkflow, :all_of)
    execute_workflow(FutureWorkflow, :set_result)
    execute_workflow(FutureWorkflow, :set_failure)
    execute_workflow(FutureWorkflow, :cancel) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      handle.cancel
      assert_equal 'done', handle.result
    end
  end

  class FiberYieldWorkflow < Temporalio::Workflow::Definition
    def execute
      @fiber = Fiber.current
      Fiber.yield
    end

    workflow_signal
    def finish_workflow(value)
      Temporalio::Workflow.wait_condition { @fiber }.resume(value)
    end
  end

  def test_fiber_yield
    execute_workflow(FiberYieldWorkflow) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      handle.signal(FiberYieldWorkflow.finish_workflow, 'some-value')
      assert_equal 'some-value', handle.result
    end
  end

  class PayloadCodecActivity < Temporalio::Activity::Definition
    def execute(should_fail)
      raise Temporalio::Error::ApplicationError.new('Oh no', 'some err detail') if should_fail

      'some activity output'
    end
  end

  class PayloadCodecWorkflow < Temporalio::Workflow::Definition
    def execute(should_fail)
      # Activity
      act_res = Temporalio::Workflow.execute_activity(
        PayloadCodecActivity, should_fail,
        start_to_close_timeout: 10,
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
      )
      raise 'Bad act result' if act_res != 'some activity output'

      # SA
      raise 'Bad SA' if Temporalio::Workflow.search_attributes[Test::ATTR_KEY_TEXT] != 'some-sa'

      Temporalio::Workflow.upsert_search_attributes(Test::ATTR_KEY_TEXT.value_set('new-sa'))

      # Memo
      raise 'Bad memo' if Temporalio::Workflow.memo['some-memo-key'] != 'some-memo'

      Temporalio::Workflow.upsert_memo({ 'some-memo-key' => 'new-memo' })

      Temporalio::Workflow.wait_condition { @finish_with }
    end

    workflow_signal
    def some_signal(finish_with)
      @finish_with = finish_with
    end

    workflow_query
    def some_query(input)
      "query output from input: #{input}"
    end

    workflow_update
    def some_update(input)
      "update output from input: #{input}"
    end
  end

  def test_payload_codec
    env.ensure_common_search_attribute_keys

    # Create a new client with the base64 codec
    new_options = env.client.options.with(
      data_converter: Temporalio::Converters::DataConverter.new(payload_codec: Base64Codec.new)
    )
    client = Temporalio::Client.new(**new_options.to_h)
    assert_encoded = lambda do |payload|
      assert_equal 'test/base64', payload.metadata['encoding']
      Base64.strict_decode64(payload.data)
    end

    # Workflow success and many common payload paths
    execute_workflow(
      PayloadCodecWorkflow, false,
      activities: [PayloadCodecActivity],
      search_attributes: Temporalio::SearchAttributes.new({ ATTR_KEY_TEXT => 'some-sa' }),
      memo: { 'some-memo-key' => 'some-memo' },
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      # Check query, update, signal, and workflow result
      query_result = handle.query(PayloadCodecWorkflow.some_query, 'query-input')
      assert_equal 'query output from input: query-input', query_result
      update_result = handle.execute_update(PayloadCodecWorkflow.some_update, 'update-input')
      assert_equal 'update output from input: update-input', update_result
      handle.signal(PayloadCodecWorkflow.some_signal, 'some-workflow-result')
      assert_equal 'some-workflow-result', handle.result

      # Now check that history has encoded values, with the exception of search attributes
      events = handle.fetch_history_events

      # Start
      attrs = events.map(&:workflow_execution_started_event_attributes).compact.first
      assert_encoded.call(attrs.input.payloads.first)
      assert_encoded.call(attrs.memo.fields['some-memo-key'])
      assert_equal 'json/plain', attrs.search_attributes.indexed_fields[ATTR_KEY_TEXT.name].metadata['encoding']

      # Activity
      attrs = events.map(&:activity_task_scheduled_event_attributes).compact.first
      assert_encoded.call(attrs.input.payloads.first)
      attrs = events.map(&:activity_task_completed_event_attributes).compact.first
      assert_encoded.call(attrs.result.payloads.first)

      # Upserts
      attrs = events.map(&:upsert_workflow_search_attributes_event_attributes).compact.first
      assert_equal 'json/plain', attrs.search_attributes.indexed_fields[ATTR_KEY_TEXT.name].metadata['encoding']
      attrs = events.map(&:workflow_properties_modified_event_attributes).compact.first
      assert_encoded.call(attrs.upserted_memo.fields['some-memo-key'])

      # Signal and update
      attrs = events.map(&:workflow_execution_signaled_event_attributes).compact.first
      assert_encoded.call(attrs.input.payloads.first)
      attrs = events.map(&:workflow_execution_update_accepted_event_attributes).compact.first
      assert_encoded.call(attrs.accepted_request.input.args.payloads.first)
      attrs = events.map(&:workflow_execution_update_completed_event_attributes).compact.first
      assert_encoded.call(attrs.outcome.success.payloads.first)

      # Check SA and memo on describe
      desc = handle.describe
      assert_equal 'new-sa', desc.search_attributes[ATTR_KEY_TEXT]
      assert_equal 'new-memo', desc.memo['some-memo-key']
    end

    # Workflow failure
    execute_workflow(
      PayloadCodecWorkflow, true,
      activities: [PayloadCodecActivity],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_instance_of Temporalio::Error::ActivityError, err.cause
      assert_instance_of Temporalio::Error::ApplicationError, err.cause.cause
      assert_equal 'Oh no', err.cause.cause.message
      assert_equal 'some err detail', err.cause.cause.details.first

      # Error message not encoded, but details are
      events = handle.fetch_history_events
      attrs = events.map(&:activity_task_failed_event_attributes).compact.first
      assert_equal 'Oh no', attrs.failure.message
      assert_encoded.call(attrs.failure.application_failure_info.details.payloads.first)
    end

    # Workflow failure with failure encoding
    new_options = env.client.options.with(
      data_converter: Temporalio::Converters::DataConverter.new(
        failure_converter: Temporalio::Converters::FailureConverter.new(encode_common_attributes: true),
        payload_codec: Base64Codec.new
      )
    )
    client = Temporalio::Client.new(**new_options.to_h)
    execute_workflow(
      PayloadCodecWorkflow, true,
      activities: [PayloadCodecActivity],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |handle|
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_instance_of Temporalio::Error::ActivityError, err.cause
      assert_instance_of Temporalio::Error::ApplicationError, err.cause.cause
      assert_equal 'Oh no', err.cause.cause.message
      assert_equal 'some err detail', err.cause.cause.details.first

      # Error message is encoded
      events = handle.fetch_history_events
      attrs = events.map(&:activity_task_failed_event_attributes).compact.first
      assert_equal 'Encoded failure', attrs.failure.message
    end
  end

  class DynamicWorkflow < Temporalio::Workflow::Definition
    workflow_dynamic
    workflow_raw_args

    def execute(*raw_args)
      raise 'Bad arg' unless raw_args.all? { |v| v.is_a?(Temporalio::Converters::RawValue) }

      res = raw_args.map { |v| Temporalio::Workflow.payload_converter.from_payload(v.payload) }.join(' -- ')
      res = "#{Temporalio::Workflow.info.workflow_type} - #{res}"
      # Wrap result in raw arg to test that too
      Temporalio::Converters::RawValue.new(Temporalio::Workflow.payload_converter.to_payload(res))
    end
  end

  class NonDynamicWorkflow < Temporalio::Workflow::Definition
    def execute(input)
      "output for input: #{input}"
    end
  end

  def test_dynamic
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [DynamicWorkflow, NonDynamicWorkflow]
    )
    worker.run do
      # Non-dynamic
      res = env.client.execute_workflow(
        NonDynamicWorkflow, 'some-input1',
        id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue
      )
      assert_equal 'output for input: some-input1', res
      res = env.client.execute_workflow(
        'NonDynamicWorkflow', 'some-input2',
        id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue
      )
      assert_equal 'output for input: some-input2', res

      # Dynamic directly fails
      err = assert_raises(ArgumentError) do
        env.client.execute_workflow(
          DynamicWorkflow, 'some-input3',
          id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue
        )
      end
      assert_includes err.message, 'Cannot pass dynamic workflow to start'

      # Dynamic
      res = env.client.execute_workflow(
        'NonDynamicWorkflowTypo', 'some-input4', 'some-input5',
        id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue
      )
      assert_equal 'NonDynamicWorkflowTypo - some-input4 -- some-input5', res
    end
  end

  class ContextFrozenWorkflow < Temporalio::Workflow::Definition
    workflow_init
    def initialize(scenario = :do_nothing)
      do_bad_thing(scenario)
    end

    def execute(_scenario = :do_nothing)
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_query
    def some_query(scenario)
      do_bad_thing(scenario)
    end

    workflow_update
    def some_update(scenario)
      # Do nothing inside the update itself
    end

    workflow_update_validator :some_update
    def some_update_validator(scenario)
      do_bad_thing(scenario)
    end

    def do_bad_thing(scenario)
      case scenario.to_sym
      when :make_command
        Temporalio::Workflow.upsert_memo({ foo: 'bar' })
      when :fiber_schedule
        Fiber.schedule { 'foo' }
      when :wait_condition
        Temporalio::Workflow.wait_condition { true }
      when :do_nothing
        # Do nothing
      else
        raise NotImplementedError
      end
    end
  end

  def test_context_frozen
    # Init
    execute_workflow(ContextFrozenWorkflow, :make_command) do |handle|
      assert_eventually_task_fail(handle:, message_contains: 'Cannot add commands in this context')
    end
    execute_workflow(ContextFrozenWorkflow, :fiber_schedule) do |handle|
      assert_eventually_task_fail(handle:, message_contains: 'Cannot schedule fibers in this context')
    end
    execute_workflow(ContextFrozenWorkflow, :wait_condition) do |handle|
      assert_eventually_task_fail(handle:, message_contains: 'Cannot wait in this context')
    end

    # Query
    execute_workflow(ContextFrozenWorkflow) do |handle|
      err = assert_raises(Temporalio::Error::WorkflowQueryFailedError) do
        handle.query(ContextFrozenWorkflow.some_query, :make_command)
      end
      assert_includes err.message, 'Cannot add commands in this context'
      err = assert_raises(Temporalio::Error::WorkflowQueryFailedError) do
        handle.query(ContextFrozenWorkflow.some_query, :fiber_schedule)
      end
      assert_includes err.message, 'Cannot schedule fibers in this context'
      err = assert_raises(Temporalio::Error::WorkflowQueryFailedError) do
        handle.query(ContextFrozenWorkflow.some_query, :wait_condition)
      end
      assert_includes err.message, 'Cannot wait in this context'
    end

    # Update
    execute_workflow(ContextFrozenWorkflow) do |handle|
      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
        handle.execute_update(ContextFrozenWorkflow.some_update, :make_command)
      end
      assert_includes err.cause.message, 'Cannot add commands in this context'
      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
        handle.execute_update(ContextFrozenWorkflow.some_update, :fiber_schedule)
      end
      assert_includes err.cause.message, 'Cannot schedule fibers in this context'
      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
        handle.execute_update(ContextFrozenWorkflow.some_update, :wait_condition)
      end
      assert_includes err.cause.message, 'Cannot wait in this context'
    end
  end

  class InitializerFailureWorkflow < Temporalio::Workflow::Definition
    workflow_init
    def initialize(scenario)
      case scenario.to_sym
      when :workflow_failure
        raise Temporalio::Error::ApplicationError, 'Intentional workflow failure'
      when :task_failure
        raise 'Intentional task failure'
      else
        raise NotImplementedError
      end
    end

    def execute(_scenario)
      'done'
    end
  end

  def test_initializer_failure
    execute_workflow(InitializerFailureWorkflow, :workflow_failure) do |handle|
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_equal 'Intentional workflow failure', err.cause.message
    end
    execute_workflow(InitializerFailureWorkflow, :task_failure) do |handle|
      assert_eventually_task_fail(handle:, message_contains: 'Intentional task failure')
    end
  end

  class QueueWorkflow < Temporalio::Workflow::Definition
    def initialize
      @queue = Temporalio::Workflow::Queue.new
    end

    def execute(timeout = nil)
      # Timeout only works on 3.2+
      if timeout
        @queue.pop(timeout:)
      else
        @queue.pop
      end
    end

    workflow_signal
    def enqueue(value)
      @queue.push(value)
    end
  end

  def test_queue
    execute_workflow(QueueWorkflow) do |handle|
      # Make sure it has started first so we're not inadvertently testing signal-with-start
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      handle.signal(QueueWorkflow.enqueue, 'some-value')
      assert_equal 'some-value', handle.result
    end

    # Timeout not added until 3.2, so can stop test here before then
    major, minor = RUBY_VERSION.split('.').take(2).map(&:to_i)
    return if major.nil? || major != 3 || minor.nil? || minor < 2

    # High timeout not reached
    execute_workflow(QueueWorkflow, 20) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      handle.signal(QueueWorkflow.enqueue, 'some-value2')
      assert_equal 'some-value2', handle.result
      handle.result
    end

    # Low timeout reached
    execute_workflow(QueueWorkflow, 1) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      assert_nil handle.result
      handle.result
    end

    # Timeout at the same time as signal sent. We are going to accomplish this by waiting for first task completion,
    # stopping worker (ensuring timer not yet fired), sending signal, waiting for both timer fire and signal events to
    # be present, then starting worker again. Hopefully 2 seconds is enough to catch the space between timer started but
    # not fired.
    orig_handle, task_queue = execute_workflow(QueueWorkflow, 2, max_cached_workflows: 0) do |handle, worker|
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      [handle, worker.task_queue]
    end
    # Confirm timer not fired
    refute orig_handle.fetch_history_events.any?(&:timer_fired_event_attributes)
    # Send signal and wait for both timer fired and signaled
    orig_handle.signal(QueueWorkflow.enqueue, 'some-value3')
    assert_eventually { assert orig_handle.fetch_history_events.any?(&:timer_fired_event_attributes) }
    assert_eventually { assert orig_handle.fetch_history_events.any?(&:workflow_execution_signaled_event_attributes) }
    # Start worker (not workflow though)
    execute_workflow(
      QueueWorkflow, 2,
      task_queue:, id: orig_handle.id,
      id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::USE_EXISTING, max_cached_workflows: 0
    ) do |handle|
      assert_equal orig_handle.result_run_id, handle.result_run_id
      assert_equal 'some-value3', handle.result
    end
  end

  class SizedQueueWorkflow < Temporalio::Workflow::Definition
    def initialize
      @queue = Temporalio::Workflow::SizedQueue.new(1)
    end

    def execute(timeout = nil)
      queue = Temporalio::Workflow::SizedQueue.new(1)
      queue.push('some-value')
      # Timeout only works on 3.2+
      raise 'Expected nil' if timeout && !queue.push('some-other-value', timeout:).nil?

      queue.pop
    end
  end

  def test_sized_queue
    assert_equal 'some-value', execute_workflow(SizedQueueWorkflow)

    # Timeout not added until 3.2, so can stop test here before then
    major, minor = RUBY_VERSION.split('.').take(2).map(&:to_i)
    return if major.nil? || major != 3 || minor.nil? || minor < 2

    execute_workflow(SizedQueueWorkflow, 0.1) do |handle|
      assert_equal 'some-value', handle.result
      # Make sure a timer event is in there
      evt = handle.fetch_history_events.find(&:timer_started_event_attributes)
      assert_equal 0.1, evt&.timer_started_event_attributes&.start_to_fire_timeout&.to_f # rubocop:disable Style/SafeNavigationChainLength
    end
  end

  class MutexActivity < Temporalio::Activity::Definition
    def initialize(queue)
      @queue = queue
    end

    def execute
      @queue.pop
    end
  end

  class MutexWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :results

    def initialize
      @mutex = Temporalio::Workflow::Mutex.new
      @results = []
    end

    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_signal
    def run_activity
      @mutex.synchronize do
        @results << Temporalio::Workflow.execute_activity(MutexActivity, start_to_close_timeout: 100)
      end
    end
  end

  def test_mutex
    queue = Queue.new
    execute_workflow(MutexWorkflow, activities: [MutexActivity.new(queue)]) do |handle|
      # Send 3 signals and make sure all are in history
      3.times { handle.signal(MutexWorkflow.run_activity) }
      assert_eventually do
        assert_equal 3, handle.fetch_history_events.count(&:workflow_execution_signaled_event_attributes)
      end

      # Now finish 3 activities, checking result each time
      queue << 'one'
      assert_eventually { assert_equal ['one'], handle.query(MutexWorkflow.results) }
      queue << 'two'
      assert_eventually { assert_equal %w[one two], handle.query(MutexWorkflow.results) }
      queue << 'three'
      assert_eventually { assert_equal %w[one two three], handle.query(MutexWorkflow.results) }
    end
  end

  class MutexSleepWorkflow < Temporalio::Workflow::Definition
    def initialize
      @mutex = Temporalio::Workflow::Mutex.new
    end

    def execute
      @mutex.synchronize do
        @mutex.sleep(0.5)
        'done'
      end
    end
  end

  def test_mutex_sleep
    assert_equal 'done', execute_workflow(MutexSleepWorkflow)
  end

  class UtilitiesWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :result

    def execute
      @result = [
        Temporalio::Workflow.random.rand(100),
        Temporalio::Workflow.random.uuid,
        Temporalio::Workflow.now
      ]
    end
  end

  def test_utilities
    # Run the workflow with no cache, then query the workflow, confirm the values
    execute_workflow(UtilitiesWorkflow, max_cached_workflows: 0) do |handle|
      result = handle.result
      assert_equal result, handle.query(UtilitiesWorkflow.result)
    end
  end

  class PatchPreActivity < Temporalio::Activity::Definition
    def execute
      'pre-patch'
    end
  end

  class PatchPostActivity < Temporalio::Activity::Definition
    def execute
      'post-patch'
    end
  end

  class PatchWorkflowBase < Temporalio::Workflow::Definition
    workflow_query_attr_reader :activity_result
    attr_writer :activity_result
  end

  class PatchPreWorkflow < PatchWorkflowBase
    workflow_name :PatchWorkflow

    def execute
      self.activity_result = Temporalio::Workflow.execute_activity(PatchPreActivity, schedule_to_close_timeout: 100)
    end
  end

  class PatchWorkflow < PatchWorkflowBase
    def execute
      self.activity_result = if Temporalio::Workflow.patched('my-patch')
                               Temporalio::Workflow.execute_activity(PatchPostActivity, schedule_to_close_timeout: 100)
                             else
                               Temporalio::Workflow.execute_activity(PatchPreActivity, schedule_to_close_timeout: 100)
                             end
    end
  end

  class PatchDeprecateWorkflow < PatchWorkflowBase
    workflow_name :PatchWorkflow

    def execute
      Temporalio::Workflow.deprecate_patch('my-patch')
      self.activity_result = Temporalio::Workflow.execute_activity(PatchPostActivity, schedule_to_close_timeout: 100)
    end
  end

  class PatchPostWorkflow < PatchWorkflowBase
    workflow_name :PatchWorkflow

    def execute
      self.activity_result = Temporalio::Workflow.execute_activity(PatchPostActivity, schedule_to_close_timeout: 100)
    end
  end

  def test_patch
    task_queue = "tq-#{SecureRandom.uuid}"
    activities = [PatchPreActivity, PatchPostActivity]

    # Run pre-patch workflow
    pre_patch_id = "wf-#{SecureRandom.uuid}"
    execute_workflow(PatchPreWorkflow, activities:, id: pre_patch_id, task_queue:) do |handle|
      handle.result
      assert_equal 'pre-patch', handle.query(PatchPreWorkflow.activity_result)
    end

    # Patch workflow and confirm pre-patch and patched work
    patched_id = "wf-#{SecureRandom.uuid}"
    execute_workflow(PatchWorkflow, activities:, id: patched_id, task_queue:) do |handle|
      handle.result
      assert_equal 'post-patch', handle.query(PatchWorkflow.activity_result)
      assert_equal 'pre-patch', env.client.workflow_handle(pre_patch_id).query(PatchWorkflow.activity_result)
    end

    # Deprecate patch and confirm patched and deprecated work, but not pre-patch
    deprecate_patch_id = "wf-#{SecureRandom.uuid}"
    execute_workflow(PatchDeprecateWorkflow, activities:, id: deprecate_patch_id, task_queue:) do |handle|
      handle.result
      assert_equal 'post-patch', handle.query(PatchWorkflow.activity_result)
      assert_equal 'post-patch', env.client.workflow_handle(patched_id).query(PatchWorkflow.activity_result)
      err = assert_raises(Temporalio::Error::WorkflowQueryFailedError) do
        env.client.workflow_handle(pre_patch_id).query(PatchWorkflow.activity_result)
      end
      assert_includes err.message, 'Nondeterminism'
    end

    # Remove patch and confirm post patch and deprecated work, but not pre-patch or patched
    post_patch_id = "wf-#{SecureRandom.uuid}"
    execute_workflow(PatchPostWorkflow, activities:, id: post_patch_id, task_queue:) do |handle|
      handle.result
      assert_equal 'post-patch', handle.query(PatchWorkflow.activity_result)
      assert_equal 'post-patch', env.client.workflow_handle(deprecate_patch_id).query(PatchWorkflow.activity_result)
      err = assert_raises(Temporalio::Error::WorkflowQueryFailedError) do
        env.client.workflow_handle(pre_patch_id).query(PatchWorkflow.activity_result)
      end
      assert_includes err.message, 'Nondeterminism'
      err = assert_raises(Temporalio::Error::WorkflowQueryFailedError) do
        env.client.workflow_handle(patched_id).query(PatchWorkflow.activity_result)
      end
      assert_includes err.message, 'Nondeterminism'
    end
  end

  class CustomMetricsActivity < Temporalio::Activity::Definition
    def execute
      counter = Temporalio::Activity::Context.current.metric_meter.create_metric(
        :counter, 'my-activity-counter'
      ).with_additional_attributes({ someattr: 'someval1' })
      counter.record(123, additional_attributes: { anotherattr: 'anotherval1' })
      'done'
    end
  end

  class CustomMetricsWorkflow < Temporalio::Workflow::Definition
    def execute
      histogram = Temporalio::Workflow.metric_meter.create_metric(
        :histogram, 'my-workflow-histogram', value_type: :duration
      ).with_additional_attributes({ someattr: 'someval2' })
      histogram.record(4.56, additional_attributes: { anotherattr: 'anotherval2' })
      Temporalio::Workflow.execute_activity(CustomMetricsActivity, schedule_to_close_timeout: 10)
    end
  end

  def test_custom_metrics
    # Create a client w/ a Prometheus-enabled runtime
    prom_addr = "127.0.0.1:#{find_free_port}"
    runtime = Temporalio::Runtime.new(
      telemetry: Temporalio::Runtime::TelemetryOptions.new(
        metrics: Temporalio::Runtime::MetricsOptions.new(
          prometheus: Temporalio::Runtime::PrometheusMetricsOptions.new(
            bind_address: prom_addr
          )
        )
      )
    )
    conn_opts = env.client.connection.options.with(runtime:)
    client_opts = env.client.options.with(
      connection: Temporalio::Client::Connection.new(**conn_opts.to_h)
    )
    client = Temporalio::Client.new(**client_opts.to_h) # steep:ignore

    assert_equal 'done', execute_workflow(
      CustomMetricsWorkflow,
      activities: [CustomMetricsActivity],
      client:
    )

    dump = Net::HTTP.get(URI("http://#{prom_addr}/metrics"))
    lines = dump.split("\n")

    # Confirm we have the regular activity metrics
    line = lines.find { |l| l.start_with?('temporal_activity_task_received{') }
    assert_includes line, 'activity_type="CustomMetricsActivity"'
    assert_includes line, 'task_queue="'
    assert_includes line, 'namespace="default"'
    assert line.end_with?(' 1')

    # Confirm we have the regular workflow metrics
    line = lines.find { |l| l.start_with?('temporal_workflow_completed{') }
    assert_includes line, 'workflow_type="CustomMetricsWorkflow"'
    assert_includes line, 'task_queue="'
    assert_includes line, 'namespace="default"'
    assert line.end_with?(' 1')

    # Confirm custom activity metric has the tags we expect
    line = lines.find { |l| l.start_with?('my_activity_counter{') }
    assert_includes line, 'activity_type="CustomMetricsActivity"'
    assert_includes line, 'task_queue="'
    assert_includes line, 'namespace="default"'
    assert_includes line, 'someattr="someval1"'
    assert_includes line, 'anotherattr="anotherval1"'
    assert line.end_with?(' 123')

    # Confirm custom workflow metric has the tags we expect
    line = lines.find { |l| l.start_with?('my_workflow_histogram_sum{') }
    assert_includes line, 'workflow_type="CustomMetricsWorkflow"'
    assert_includes line, 'task_queue="'
    assert_includes line, 'namespace="default"'
    assert_includes line, 'someattr="someval2"'
    assert_includes line, 'anotherattr="anotherval2"'
    assert line.end_with?(' 4560')
  end

  def test_workflow_buffered_metrics
    # Create runtime with metric buffer
    buffer = Temporalio::Runtime::MetricBuffer.new(10_000)
    runtime = Temporalio::Runtime.new(
      telemetry: Temporalio::Runtime::TelemetryOptions.new(metrics: Temporalio::Runtime::MetricsOptions.new(buffer:))
    )

    # Confirm nothing there yet
    assert_equal [], buffer.retrieve_updates

    # Create a counter and make one with more attrs
    runtime_counter = runtime.metric_meter.create_metric(
      :counter, 'runtime-counter', description: 'runtime-counter-desc', unit: 'runtime-counter-unit'
    )
    runtime_counter_with_attrs = runtime_counter.with_additional_attributes({ 'foo' => 'bar', 'baz' => 123 })

    # Send adds to both
    runtime_counter.record(100)
    runtime_counter_with_attrs.record(200)

    # Get updates and check their values
    updates1 = buffer.retrieve_updates
    assert_equal [
      Temporalio::Runtime::MetricBuffer::Update.new(
        metric: Temporalio::Runtime::MetricBuffer::Metric.new(
          name: 'runtime-counter', description: 'runtime-counter-desc', unit: 'runtime-counter-unit', kind: :counter
        ),
        value: 100,
        attributes: { 'service_name' => 'temporal-core-sdk' }
      ),
      Temporalio::Runtime::MetricBuffer::Update.new(
        metric: Temporalio::Runtime::MetricBuffer::Metric.new(
          name: 'runtime-counter', description: 'runtime-counter-desc', unit: 'runtime-counter-unit', kind: :counter
        ),
        value: 200,
        attributes: { 'service_name' => 'temporal-core-sdk', 'foo' => 'bar', 'baz' => 123 }
      )
    ], updates1
    # Also confirm that for performance reasons the metrics are actually the same object
    assert_same updates1.first.metric, updates1.last.metric

    # Confirm no more updates
    assert_equal [], buffer.retrieve_updates

    # Send some more adds and check
    runtime_counter.record(300)
    runtime_counter_with_attrs.record(400)
    updates2 = buffer.retrieve_updates
    assert_equal 2, updates2.size
    assert_same updates1.first.metric, updates2.first.metric
    assert_same updates1.first.attributes, updates2.first.attributes
    assert_equal 300, updates2.first.value
    assert_same updates1.last.metric, updates2.last.metric
    assert_same updates1.last.attributes, updates2.last.attributes
    assert_equal 400, updates2.last.value

    # Confirm no more updates
    assert_equal [], buffer.retrieve_updates

    # Test simple gauge
    runtime_gauge = runtime.metric_meter.create_metric(:gauge, 'runtime-gauge', value_type: :float)
    runtime_gauge.record(1.23, additional_attributes: { 'somekey' => true })
    updates3 = buffer.retrieve_updates
    assert_equal [
      Temporalio::Runtime::MetricBuffer::Update.new(
        metric: Temporalio::Runtime::MetricBuffer::Metric.new(
          name: 'runtime-gauge', description: nil, unit: nil, kind: :gauge
        ),
        value: 1.23,
        attributes: { 'service_name' => 'temporal-core-sdk', 'somekey' => true }
      )
    ], updates3

    # Confirm no more updates
    assert_equal [], buffer.retrieve_updates

    # Create a new client on the runtime and execute the custom metric workflow
    conn_opts = env.client.connection.options.with(runtime:)
    client_opts = env.client.options.with(
      connection: Temporalio::Client::Connection.new(**conn_opts.to_h)
    )
    client = Temporalio::Client.new(**client_opts.to_h) # steep:ignore
    task_queue = "tq-#{SecureRandom.uuid}"
    assert_equal 'done', execute_workflow(
      CustomMetricsWorkflow,
      activities: [CustomMetricsActivity],
      client:,
      task_queue:
    )

    # Drain updates and confirm updates exist as expected
    updates = buffer.retrieve_updates
    # Workflow histogram
    assert_includes updates, Temporalio::Runtime::MetricBuffer::Update.new(
      metric: Temporalio::Runtime::MetricBuffer::Metric.new(
        name: 'my-workflow-histogram', description: nil, unit: nil, kind: :histogram
      ),
      value: 4560,
      attributes: {
        'service_name' => 'temporal-core-sdk',
        'namespace' => 'default',
        'task_queue' => task_queue,
        'workflow_type' => 'CustomMetricsWorkflow',
        'someattr' => 'someval2',
        'anotherattr' => 'anotherval2'
      }
    )
    # Activity counter
    assert_includes updates, Temporalio::Runtime::MetricBuffer::Update.new(
      metric: Temporalio::Runtime::MetricBuffer::Metric.new(
        name: 'my-activity-counter', description: nil, unit: nil, kind: :counter
      ),
      value: 123,
      attributes: {
        'service_name' => 'temporal-core-sdk',
        'namespace' => 'default',
        'task_queue' => task_queue,
        'activity_type' => 'CustomMetricsActivity',
        'someattr' => 'someval1',
        'anotherattr' => 'anotherval1'
      }
    )
  end

  class FailWorkflowPayloadConverter < Temporalio::Converters::PayloadConverter
    def to_payload(value, hint: nil)
      if value == 'fail-on-this-result'
        raise Temporalio::Error::ApplicationError.new('Intentional error', type: 'IntentionalError')
      end

      Temporalio::Converters::PayloadConverter.default.to_payload(value, hint:)
    end

    def from_payload(payload, hint: nil)
      value = Temporalio::Converters::PayloadConverter.default.from_payload(payload, hint:)
      if value == 'fail-on-this'
        raise Temporalio::Error::ApplicationError.new('Intentional error', type: 'IntentionalError')
      end

      value
    end
  end

  class FailWorkflowPayloadConverterWorkflow < Temporalio::Workflow::Definition
    def execute(arg)
      if arg == 'fail'
        "#{arg}-on-this-result"
      else
        Temporalio::Workflow.wait_condition { false }
      end
    end

    workflow_update
    def do_update(arg)
      "#{arg}-on-this-result"
    end
  end

  def test_fail_workflow_payload_converter
    new_options = env.client.options.with(
      data_converter: Temporalio::Converters::DataConverter.new(payload_converter: FailWorkflowPayloadConverter.new)
    )
    client = Temporalio::Client.new(**new_options.to_h)

    # As workflow argument
    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(FailWorkflowPayloadConverterWorkflow, 'fail-on-this', client:)
    end
    assert_equal 'IntentionalError', err.cause.type

    # As workflow result
    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(FailWorkflowPayloadConverterWorkflow, 'fail', client:)
    end
    assert_equal 'IntentionalError', err.cause.type

    # As an update argument
    err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
      execute_workflow(FailWorkflowPayloadConverterWorkflow, 'do-nothing', client:) do |handle|
        handle.execute_update(FailWorkflowPayloadConverterWorkflow.do_update, 'fail-on-this')
      end
    end
    # We do an extra `.cause` because this is wrapped in a RuntimeError that the update arg parsing failed
    assert_equal 'IntentionalError', err.cause.cause.type

    # As an update result
    err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
      execute_workflow(FailWorkflowPayloadConverterWorkflow, 'do-nothing', client:) do |handle|
        handle.execute_update(FailWorkflowPayloadConverterWorkflow.do_update, 'fail')
      end
    end
    assert_equal 'IntentionalError', err.cause.type
  end

  class ConfirmGarbageCollectWorkflow < Temporalio::Workflow::Definition
    @initialized_count = 0
    @finalized_count = 0
    @weak_instance = nil
    @strong_instance = nil
    @instance_object_id = nil

    class << self
      attr_accessor :initialized_count, :finalized_count,
                    :weak_instance, :strong_instance, :instance_object_id,
                    :weak_fiber, :fiber_object_id

      def create_finalizer
        proc { @finalized_count += 1 }
      end
    end

    def initialize
      self.class.initialized_count += 1
      self.class.weak_instance = WeakRef.new(self)
      # Uncomment this to cause test to fail
      # self.class.strong_instance = self
      self.class.instance_object_id = object_id
      self.class.weak_fiber = WeakRef.new(Fiber.current)
      self.class.fiber_object_id = Fiber.current.object_id

      ObjectSpace.define_finalizer(self, self.class.create_finalizer)
    end

    def execute
      Temporalio::Workflow.wait_condition { false }
    end
  end

  def test_confirm_garbage_collect
    skip('Skipping GC collection confirmation until https://github.com/temporalio/sdk-ruby/issues/334')

    # This test confirms the workflow instance is reliably GC'd when workflow/worker done. To confirm the test fails
    # when there is still an instance, uncomment the strong_instance set in the initialize of the workflow.

    execute_workflow(ConfirmGarbageCollectWorkflow) do |handle|
      # Wait until it is started
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      # Confirm initialized but not finalized
      assert_equal 1, ConfirmGarbageCollectWorkflow.initialized_count
      assert_equal 0, ConfirmGarbageCollectWorkflow.finalized_count
    end

    # Perform a GC and confirm gone. There are cases in Ruby where dead stack slots leave the item around for a bit, so
    # we check repeatedly for a bit (every 200ms for 10s). We can't use assert_eventually, because path doesn't show
    # well.
    start_time = Time.now
    loop do
      GC.start
      # Break if the instance is gone
      break unless ConfirmGarbageCollectWorkflow.weak_fiber.weakref_alive?

      # If this is last iteration, flunk w/ the path
      if Time.now - start_time > 10
        path, cat = GCUtils.find_retaining_path_to(ConfirmGarbageCollectWorkflow.fiber_object_id, max_depth: 12)
        msg = GCUtils.annotated_path(path, root_category: cat)
        msg += "\nPath:\n#{path.map { |p| "    Item: #{p}" }.join("\n")}"
        # Also display any Thread/Fiber backtraces that are in the path
        path.grep(Thread).each do |thread|
          msg += "\nThread trace: #{thread.backtrace.join("\n")}"
        end
        path.grep(Fiber).each do |fiber|
          msg += "\nFiber trace: #{fiber.backtrace.join("\n")}"
        end
        msg += "\nOrig fiber trace: #{ConfirmGarbageCollectWorkflow.weak_fiber.backtrace.join("\n")}"
        flunk msg
      end
      sleep(0.2)
    end
  end

  class ContextInstanceInterceptor
    include Temporalio::Worker::Interceptor::Workflow

    def intercept_workflow(next_interceptor)
      Inbound.new(next_interceptor)
    end

    class Inbound < Temporalio::Worker::Interceptor::Workflow::Inbound
      def execute(input)
        Temporalio::Workflow.instance.events << 'interceptor-execute'
        super
      end
    end
  end

  class ContextInstanceWorkflow < Temporalio::Workflow::Definition
    def execute
      events << 'execute'
    end

    workflow_query
    def events
      @events ||= []
    end
  end

  def test_context_instance
    assert_equal %w[interceptor-execute execute],
                 execute_workflow(ContextInstanceWorkflow, interceptors: [ContextInstanceInterceptor.new])
  end

  class WorkerClientReplacementWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { @complete }
    end

    workflow_signal
    def complete(value)
      @complete = value
    end
  end

  def test_worker_client_replacement
    # Create a second ephemeral server and start workflow on both servers
    Temporalio::Testing::WorkflowEnvironment.start_local do |env2|
      # Start both workflows on different servers
      task_queue = "tq-#{SecureRandom.uuid}"
      handle1 = env.client.start_workflow(WorkerClientReplacementWorkflow, id: "wf-#{SecureRandom.uuid}", task_queue:)
      handle2 = env2.client.start_workflow(WorkerClientReplacementWorkflow, id: "wf-#{SecureRandom.uuid}", task_queue:)

      # Run worker on the first env. Make sure cache is off and only 1 max poller
      worker = Temporalio::Worker.new(
        client: env.client, task_queue:, workflows: [WorkerClientReplacementWorkflow],
        max_cached_workflows: 0, max_concurrent_workflow_task_polls: 1
      )
      worker.run do
        # Confirm first workflow has a task complete but not the second
        assert_eventually do
          refute_nil handle1.fetch_history_events.find(&:workflow_task_completed_event_attributes)
        end
        assert_nil handle2.fetch_history_events.find(&:workflow_task_completed_event_attributes)

        # Replace the client
        worker.client = env2.client

        # Signal both which should allow the current poll to wake up and it'll be a task failure when trying to submit
        # that to the new client which is ignored. But also the new client will poll for the new workflow, which we will
        # wait for it to complete.
        handle1.signal(WorkerClientReplacementWorkflow.complete, 'done1')
        handle2.signal(WorkerClientReplacementWorkflow.complete, 'done2')

        # Confirm second workflow on new server completes
        assert_equal 'done2', handle2.result
        handle1.terminate
      end
    end
  end

  class ReservedNameDynamicActivity < Temporalio::Activity::Definition
    activity_dynamic

    def execute
      'done'
    end
  end

  class ReservedNameDynamicWorkflow < Temporalio::Workflow::Definition
    workflow_dynamic
    workflow_query_attr_reader :dyn_signals_received

    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_signal dynamic: true
    def dyn_signal(name, *)
      (@dyn_signals_received ||= []) << "signal: #{name}"
    end

    workflow_query dynamic: true
    def dyn_query(name, *)
      "query: #{name}"
    end

    workflow_update dynamic: true
    def dyn_update(name, *)
      "update: #{name}"
    end

    workflow_update
    def call_activity(name)
      Temporalio::Workflow.execute_activity(
        name,
        start_to_close_timeout: 10,
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
      )
    end
  end

  class ReservedNameInterceptor
    include Temporalio::Worker::Interceptor::Activity
    include Temporalio::Worker::Interceptor::Workflow

    attr_accessor :events

    def initialize
      @events = []
    end

    def intercept_activity(next_interceptor)
      ActivityInbound.new(self, next_interceptor)
    end

    def intercept_workflow(next_interceptor)
      WorkflowInbound.new(self, next_interceptor)
    end

    class ActivityInbound < Temporalio::Worker::Interceptor::Activity::Inbound
      def initialize(root, next_interceptor)
        super(next_interceptor)
        @root = root
      end

      def execute(input)
        @root.events.push("activity: #{Temporalio::Activity::Context.current.info.activity_type}")
        super
      end
    end

    class WorkflowInbound < Temporalio::Worker::Interceptor::Workflow::Inbound
      def initialize(root, next_interceptor)
        super(next_interceptor)
        @root = root
      end

      def execute(input)
        @root.events.push("workflow: #{Temporalio::Workflow.info.workflow_type}")
        super
      end

      def handle_signal(input)
        @root.events.push("signal: #{input.signal}")
        super
      end

      def handle_query(input)
        @root.events.push("query: #{input.query}")
        super
      end

      def handle_update(input)
        @root.events.push("update: #{input.update}")
        super
      end
    end
  end

  def test_reserved_names
    # Create worker with dyn workflow/activity and interceptor
    interceptor = ReservedNameInterceptor.new
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      activities: [ReservedNameDynamicActivity],
      workflows: [ReservedNameDynamicWorkflow],
      interceptors: [interceptor]
    )
    worker.run do
      # Try to start a workflow with reserved name
      handle = env.client.start_workflow(
        :__temporal_workflow,
        id: "wf-#{SecureRandom.uuid}",
        task_queue: worker.task_queue
      )
      assert_eventually_task_fail(handle:, message_contains: '__temporal_workflow is not registered')

      # But it's ok started a general one, and then we'll use this one to test other things
      handle = env.client.start_workflow(
        :unknown_workflow,
        id: "wf-#{SecureRandom.uuid}",
        task_queue: worker.task_queue
      )

      # Try to call an activity with reserved name
      err = assert_raises { handle.execute_update(:call_activity, :__temporal_activity) }
      assert_includes err.cause.cause.message, 'is not registered on this worker, available activities:'

      # Now try without reserved name
      assert_equal 'done', handle.execute_update(:call_activity, :unknown_activity)

      # Try calling handlers with reserved names
      handle.signal(:__temporal_signal)
      refute_includes (handle.query(:dyn_signals_received) || []), 'signal: __temporal_signal'
      err = assert_raises { handle.query(:__temporal_query) }
      assert_includes err.message, 'not found'
      err = assert_raises { handle.execute_update(:__temporal_update) }
      assert_includes err.cause.message, 'not found'

      # Now try calling handlers for non-reserved
      handle.signal(:unknown_signal)
      assert_includes handle.query(:dyn_signals_received), 'signal: unknown_signal'
      assert_equal 'query: unknown_query', handle.query(:unknown_query)
      assert_equal 'update: unknown_update', handle.execute_update(:unknown_update)

      # Make a stack trace query call that should succeed
      assert_includes handle.query(:__stack_trace), 'execute'

      # Check the interceptor contains ': unknown_' things but not ': __temporal' things or __stack_trace
      assert(interceptor.events.any? { |e| e.include?(': unknown_workflow') })
      assert(interceptor.events.any? { |e| e.include?(': unknown_activity') })
      assert(interceptor.events.any? { |e| e.include?(': unknown_signal') })
      assert(interceptor.events.any? { |e| e.include?(': unknown_query') })
      assert(interceptor.events.any? { |e| e.include?(': unknown_update') })
      assert(interceptor.events.none? { |e| e.include?(': __temporal') })
      assert(interceptor.events.none? { |e| e.include?(': __stack_trace') })
    end
  end

  class UserMetadataWorkflow < Temporalio::Workflow::Definition
    def execute(return_immediately)
      return 'done' if return_immediately

      # Timer, activity, and child with metadata
      Temporalio::Workflow.sleep(0.1, summary: 'my-timer')

      # Timeout over wait condition
      begin
        Temporalio::Workflow.timeout(0.1, summary: 'my-timeout-timer') { Temporalio::Workflow.wait_condition { false } }
        raise 'Did not timeout'
      rescue Timeout::Error
        # Ignore
      end

      # Activity
      Temporalio::Workflow.execute_activity(
        UserMetadataActivity,
        start_to_close_timeout: 30,
        summary: 'my-activity'
      )

      # Child
      Temporalio::Workflow.execute_child_workflow(
        UserMetadataWorkflow, true,
        static_summary: 'my-child', static_details: 'my-child-details'
      )
    end
  end

  class UserMetadataActivity < Temporalio::Activity::Definition
    def execute
      'done'
    end
  end

  def test_user_metadata
    execute_workflow(UserMetadataWorkflow, false, activities: [UserMetadataActivity]) do |handle|
      assert_equal 'done', handle.result
      # Check history
      events = handle.fetch_history.events
      timers = events.select(&:timer_started_event_attributes)
      assert_equal '"my-timer"', timers.first.user_metadata.summary.data
      assert_equal '"my-timeout-timer"', timers.last.user_metadata.summary.data
      assert_equal '"my-activity"', events.find(&:activity_task_scheduled_event_attributes).user_metadata.summary.data
      child = events.find(&:start_child_workflow_execution_initiated_event_attributes)
      assert_equal '"my-child"', child.user_metadata.summary.data
      assert_equal '"my-child-details"', child.user_metadata.details.data

      # Describe the child and confirm metadata
      child_desc = env.client.workflow_handle(
        child.start_child_workflow_execution_initiated_event_attributes.workflow_id
      ).describe
      assert_equal 'my-child', child_desc.static_summary
      assert_equal 'my-child-details', child_desc.static_details
    end
  end

  class WorkflowMetadataWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :continue, description: 'continue description'

    def execute
      Temporalio::Workflow.current_details = 'initial current details'
      Temporalio::Workflow.signal_handlers['some manual signal'] = Temporalio::Workflow::Definition::Signal.new(
        name: 'some manual signal',
        to_invoke: proc {},
        description: 'some manual signal description'
      )
      Temporalio::Workflow.wait_condition { @continue }
      Temporalio::Workflow.current_details = 'final current details'
    end

    workflow_signal
    def some_signal; end

    workflow_signal name: 'some signal', description: 'some signal description'
    def some_other_signal; end

    workflow_query description: 'some query description', dynamic: true
    def some_query(name, *args); end

    workflow_update description: 'some update description'
    def some_update
      @continue = true
    end

    workflow_update name: 'some update'
    def some_other_update; end
  end

  def test_workflow_metadata
    execute_workflow(WorkflowMetadataWorkflow) do |handle|
      # Check workflow metadata
      assert_equal Temporalio::Api::Sdk::V1::WorkflowMetadata.new(
        definition: Temporalio::Api::Sdk::V1::WorkflowDefinition.new(
          type: 'WorkflowMetadataWorkflow',
          query_definitions: [
            Temporalio::Api::Sdk::V1::WorkflowInteractionDefinition.new(
              name: 'continue', description: 'continue description'
            ),
            Temporalio::Api::Sdk::V1::WorkflowInteractionDefinition.new(
              description: 'some query description'
            )
          ],
          signal_definitions: [
            Temporalio::Api::Sdk::V1::WorkflowInteractionDefinition.new(
              name: 'some_signal'
            ),
            Temporalio::Api::Sdk::V1::WorkflowInteractionDefinition.new(
              name: 'some signal', description: 'some signal description'
            ),
            Temporalio::Api::Sdk::V1::WorkflowInteractionDefinition.new(
              name: 'some manual signal', description: 'some manual signal description'
            )
          ],
          update_definitions: [
            Temporalio::Api::Sdk::V1::WorkflowInteractionDefinition.new(
              name: 'some_update', description: 'some update description'
            ),
            Temporalio::Api::Sdk::V1::WorkflowInteractionDefinition.new(
              name: 'some update'
            )
          ]
        ),
        current_details: 'initial current details'
      ), handle.query(:__temporal_workflow_metadata)

      # Complete and check final details
      handle.execute_update(WorkflowMetadataWorkflow.some_update)
      handle.result
      assert_equal 'final current details', handle.query(:__temporal_workflow_metadata).current_details
    end
  end

  class UnsafeIOWorkflow < Temporalio::Workflow::Definition
    def execute(unsafe_io_enabled)
      if unsafe_io_enabled
        Temporalio::Workflow::Unsafe.io_enabled { do_http_call }
      else
        do_http_call
      end
    end

    def do_http_call
      Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled do
        Net::HTTP.get(URI('https://example.com'))
      end
    end
  end

  def test_unsafe_io
    # Ruby 3.2 on macOS has Fiber scheduling issues with IO.select
    major, minor = RUBY_VERSION.split('.').take(2).map(&:to_i)
    return if major.nil? || major != 3 || minor.nil? || minor < 3

    # Not allowed by default
    execute_workflow(UnsafeIOWorkflow, false) do |handle|
      assert_eventually_task_fail(handle:, message_contains: 'Cannot perform IO from inside a workflow')
    end

    # Allowed when enabled narrowly inside workflow
    res = execute_workflow(UnsafeIOWorkflow, true)
    assert_includes res, '<html>'

    # Allowed when enabled at worker level
    res = execute_workflow(UnsafeIOWorkflow, false, unsafe_workflow_io_enabled: true)
    assert_includes res, '<html>'
  end

  class MissingLocalActivityWorkflow < Temporalio::Workflow::Definition
    def execute
      # Start 30 10ms timers and wait on them all
      Temporalio::Workflow.execute_local_activity('does-not-exist',
                                                  start_to_close_timeout: 1000)
    end
  end

  def test_missing_local_activity
    activities = [PatchPreActivity]
    message_contains = 'Activity does-not-exist is not registered on this worker, ' \
                       'available activities: PatchPreActivity'

    execute_workflow(MissingLocalActivityWorkflow, activities:) do |handle|
      assert_eventually_task_fail(handle:,
                                  message_contains:)
    end
  end

  def test_dynamic_local_activity
    activities = [ReservedNameDynamicActivity]

    assert_equal 'done', execute_workflow(MissingLocalActivityWorkflow, activities:)
  end

  def test_no_local_activity
    message_contains = 'Activity does-not-exist is not registered on this worker, no available activities.'

    execute_workflow(MissingLocalActivityWorkflow, false) do |handle|
      assert_eventually_task_fail(handle:, message_contains:)
    end
  end

  class HintTrackingJSONConverter < Temporalio::Converters::PayloadConverter::JSONPlain
    attr_accessor :outbound_hints, :inbound_hints

    def to_payload(value, hint: nil)
      (@outbound_hints ||= []) << { value:, hint: }
      super
    end

    def from_payload(payload, hint: nil)
      super.tap { |value| (@inbound_hints ||= []) << { value:, hint: } }
    end
  end

  class HintActivity < Temporalio::Activity::Definition
    activity_arg_hint :activity_arg1, :activity_arg2
    activity_result_hint :activity_result

    def execute(_arg1, _arg2)
      'act_result'
    end
  end

  class HintWorkflow < Temporalio::Workflow::Definition
    workflow_arg_hint :workflow_arg1, :workflow_arg2
    workflow_result_hint :workflow_result

    def execute(_arg1, _arg2)
      # Complete if we're continued
      return 'wf_result' if Temporalio::Workflow.info.continued_run_id

      Temporalio::Workflow.execute_activity(HintActivity, 'act_arg1', 'act_arg2', start_to_close_timeout: 10)
      Temporalio::Workflow.wait_condition { @got_update }
      raise Temporalio::Workflow::ContinueAsNewError.new('cont_wf_arg1', 'cont_wf_arg2')
    end

    workflow_signal arg_hints: :signal_arg1
    def my_signal(_arg1)
      # No-op
    end

    workflow_query arg_hints: :query_arg1, result_hint: :query_result
    def my_query(_arg1)
      'que_result'
    end

    workflow_update arg_hints: :update_arg1, result_hint: :update_result
    def my_update(_arg1)
      # Start child workflow, send signal to it, wait for completion
      handle = Temporalio::Workflow.start_child_workflow(HintChildWorkflow, 'child_wf_arg1')
      handle.signal(HintChildWorkflow.my_signal, 'child_sig_arg1')
      handle.result
      @got_update = true
      'upd_result'
    end
  end

  class HintChildWorkflow < Temporalio::Workflow::Definition
    workflow_arg_hint :child_workflow_arg1
    workflow_result_hint :child_workflow_result

    def execute(_arg1)
      Temporalio::Workflow.wait_condition { @got_signal }
      'child_wf_result'
    end

    workflow_signal arg_hints: :child_signal_arg1
    def my_signal(_arg1)
      @got_signal = true
    end
  end

  class HintWithStartWorkflow < Temporalio::Workflow::Definition
    # Intentionally one less hint than args and no result hint
    workflow_arg_hint :with_start_arg1

    def execute(_arg1, _arg2)
      Temporalio::Workflow.wait_condition { @result }
    end

    workflow_signal arg_hints: :with_start_signal_arg1
    def my_signal(_arg1)
      @result = 'sig_with_start_wf_result'
    end

    # Intentionally no arg hint
    workflow_update result_hint: :with_start_update_result
    def my_update(_arg1)
      @result = 'upd_with_start_wf_result'
      'upd_with_start_upd_result'
    end
  end

  def test_hints
    # New client with tracking JSON converter
    conv = HintTrackingJSONConverter.new
    client = Temporalio::Client.new(**env.client.options.with(
      data_converter: Temporalio::Converters::DataConverter.new(
        payload_converter: Temporalio::Converters::PayloadConverter::Composite.new(
          *Temporalio::Converters::PayloadConverter.default.converters.values.map do |c|
            c.is_a?(Temporalio::Converters::PayloadConverter::JSONPlain) ? conv : c
          end
        )
      )
    ).to_h)
    @expected_outbound_hints = []
    @expected_inbound_hints = []

    # Start worker
    task_queue = "tq-#{SecureRandom.uuid}"
    Temporalio::Worker.new(client:, task_queue:,
                           workflows: [HintWorkflow, HintChildWorkflow, HintWithStartWorkflow],
                           activities: [HintActivity]).run do
      # Run workflow
      wf_hints = [{ value: 'wf_arg1', hint: :workflow_arg1 },
                  { value: 'wf_arg2', hint: :workflow_arg2 },
                  { value: 'wf_result', hint: :workflow_result }]
      act_hints = [{ value: 'act_arg1', hint: :activity_arg1 },
                   { value: 'act_arg2', hint: :activity_arg2 },
                   { value: 'act_result', hint: :activity_result }]
      @expected_outbound_hints.push(*wf_hints, *act_hints)
      @expected_inbound_hints.push(*wf_hints, *act_hints)
      handle = client.start_workflow(
        HintWorkflow,
        'wf_arg1', 'wf_arg2',
        id: "wf-#{SecureRandom.uuid}", task_queue:
      )

      # Send messages
      msg_hints = [{ value: 'sig_arg1', hint: :signal_arg1 },
                   { value: 'que_arg1', hint: :query_arg1 },
                   { value: 'que_result', hint: :query_result },
                   { value: 'upd_arg1', hint: :update_arg1 },
                   { value: 'upd_result', hint: :update_result }]
      @expected_outbound_hints.push(*msg_hints)
      @expected_inbound_hints.push(*msg_hints)
      handle.signal(HintWorkflow.my_signal, 'sig_arg1')
      assert_equal 'que_result', handle.query(HintWorkflow.my_query, 'que_arg1')
      assert_equal 'upd_result', handle.execute_update(HintWorkflow.my_update, 'upd_arg1')

      # Other things that happened
      child_hints = [{ value: 'child_wf_arg1', hint: :child_workflow_arg1 },
                     { value: 'child_sig_arg1', hint: :child_signal_arg1 },
                     { value: 'child_wf_result', hint: :child_workflow_result }]
      cont_hints = [{ value: 'cont_wf_arg1', hint: :workflow_arg1 },
                    { value: 'cont_wf_arg2', hint: :workflow_arg2 }]
      @expected_outbound_hints.push(*child_hints, *cont_hints)
      @expected_inbound_hints.push(*child_hints, *cont_hints)

      # Check result
      assert_equal 'wf_result', handle.result

      # Signal with start
      sig_with_start_hints = [{ value: 'sig_with_start_wf_arg1', hint: :with_start_arg1 },
                              { value: 'sig_with_start_wf_arg2', hint: nil },
                              { value: 'sig_with_start_sig_arg1', hint: :with_start_signal_arg1 },
                              { value: 'sig_with_start_wf_result', hint: nil }]
      @expected_outbound_hints.push(*sig_with_start_hints)
      @expected_inbound_hints.push(*sig_with_start_hints)
      start_workflow_operation = Temporalio::Client::WithStartWorkflowOperation.new(
        HintWithStartWorkflow, 'sig_with_start_wf_arg1', 'sig_with_start_wf_arg2',
        id: "wf-#{SecureRandom.uuid}", task_queue:
      )
      client.signal_with_start_workflow(
        HintWithStartWorkflow.my_signal, 'sig_with_start_sig_arg1',
        start_workflow_operation:
      )
      assert_equal 'sig_with_start_wf_result', start_workflow_operation.workflow_handle.result

      # Update with start
      upd_with_start_hints = [{ value: 'upd_with_start_wf_arg1', hint: :with_start_arg1 },
                              { value: 'upd_with_start_wf_arg2', hint: nil },
                              { value: 'upd_with_start_upd_arg1', hint: nil },
                              { value: 'upd_with_start_upd_result', hint: :with_start_update_result },
                              { value: 'upd_with_start_wf_result', hint: nil }]
      @expected_outbound_hints.push(*upd_with_start_hints)
      @expected_inbound_hints.push(*upd_with_start_hints)
      start_workflow_operation = Temporalio::Client::WithStartWorkflowOperation.new(
        HintWithStartWorkflow, 'upd_with_start_wf_arg1', 'upd_with_start_wf_arg2',
        id: "wf-#{SecureRandom.uuid}", task_queue:, id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::FAIL
      )
      assert_equal 'upd_with_start_upd_result', client.execute_update_with_start_workflow(
        HintWithStartWorkflow.my_update, 'upd_with_start_upd_arg1',
        start_workflow_operation:
      )
      assert_equal 'upd_with_start_wf_result', start_workflow_operation.workflow_handle.result
    end

    # Check hints
    assert_equal @expected_outbound_hints.to_set, conv.outbound_hints.to_set
    assert_equal @expected_inbound_hints.to_set, conv.inbound_hints.to_set
  end

  class NonDurableTimerWorkfow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.sleep(0.1)
      Temporalio::Workflow::Unsafe.durable_scheduler_disabled { sleep(0.2) }
      begin
        Temporalio::Workflow.timeout(0.3) { Temporalio::Workflow::Queue.new.pop }
        raise 'Expected timeout'
      rescue Timeout::Error
        # Ignore
      end
      Temporalio::Workflow::Unsafe.durable_scheduler_disabled do
        Timeout.timeout(0.4) { Queue.new.pop }
        raise 'Expected timeout'
      rescue Timeout::Error
        # Ignore
      end
    end
  end

  def test_non_durable_timer
    execute_workflow(NonDurableTimerWorkfow) do |handle|
      # Let workflow complete
      handle.result
      # Confirm only the durable timers of 0.1 and 0.3 were set
      assert_equal([0.1, 0.3], handle.fetch_history_events
                                     .map(&:timer_started_event_attributes)
                                     .compact
                                     .map { |a| a.start_to_fire_timeout.to_f })
    end
  end
end

# TODO(cretz): To test
# * Common
#   * Eager workflow start
#   * Unawaited futures that have exceptions, need to log warning like Java does
#   * Enhanced stack trace?
#   * Separate abstract/interface demonstration
#   * Reset update randomness seed
#   * Confirm thread pool does not leak, meaning thread/worker goes away after last workflow
#   * Test workflow cancel causing other cancels at the same time but in different coroutines
#   * 0-sleep timers vs nil timers
#   * Interceptors
# * Activity
#   * Local activity cancel (currently broken)
