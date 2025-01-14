# frozen_string_literal: true

require 'base64_codec'
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
      when :time_now
        Time.now
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
    exec.call(:time_now, 'Time now')
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
      Temporalio::Workflow.info.to_h
    end
  end

  def test_info
    execute_workflow(InfoWorkflow) do |handle, worker|
      info = handle.result #: Hash[String, untyped]
      assert_equal 1, info['attempt']
      assert_nil info.fetch('continued_run_id')
      assert_nil info.fetch('cron_schedule')
      assert_nil info.fetch('execution_timeout')
      assert_nil info.fetch('last_failure')
      assert_nil info.fetch('last_result')
      assert_equal env.client.namespace, info['namespace']
      assert_nil info.fetch('parent')
      assert_nil info.fetch('retry_policy')
      assert_equal handle.result_run_id, info['run_id']
      assert_nil info.fetch('run_timeout')
      refute_nil info['start_time']
      assert_equal worker.task_queue, info['task_queue']
      assert_equal 10.0, info['task_timeout']
      assert_equal handle.id, info['workflow_id']
      assert_equal 'InfoWorkflow', info['workflow_type']
    end
  end

  class HistoryInfoWorkflow < Temporalio::Workflow::Definition
    def execute
      # Start 30 10ms timers and wait on them all
      Temporalio::Workflow::Future.all_of(
        *30.times.map { Temporalio::Workflow::Future.new { sleep(0.1) } }
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
        Timeout.timeout(0.1) do
          Temporalio::Workflow.wait_condition { false }
        end
      when :manual_cancel
        my_cancel, my_cancel_proc = Temporalio::Cancellation.new
        Temporalio::Workflow::Future.new do
          sleep(0.1)
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
      when :sleep_stdlib
        sleep(0.11)
      when :sleep_workflow
        Temporalio::Workflow.sleep(0.12, summary: 'my summary')
      when :sleep_stdlib_workflow_cancel
        sleep(1000)
      when :sleep_workflow_cancel
        Temporalio::Workflow.sleep(1000)
      when :sleep_explicit_cancel
        my_cancel, my_cancel_proc = Temporalio::Cancellation.new
        Temporalio::Workflow::Future.new do
          sleep(0.1)
          my_cancel_proc.call(reason: 'my cancel reason')
        end
        Temporalio::Workflow.sleep(1000, cancellation: my_cancel)
      when :sleep_cancel_before_start
        my_cancel, my_cancel_proc = Temporalio::Cancellation.new
        my_cancel_proc.call(reason: 'my cancel reason')
        Temporalio::Workflow.sleep(1000, cancellation: my_cancel)
      when :timeout_stdlib
        Timeout.timeout(0.16) do
          Temporalio::Workflow.wait_condition { false }
        end
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
        Timeout.timeout(1000) do
          Temporalio::Workflow.wait_condition { false }
        end
      when :timeout_not_reached
        Timeout.timeout(1000) do
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
    event = execute_workflow(TimerWorkflow, :sleep_stdlib) do |handle|
      handle.result
      handle.fetch_history_events.find(&:timer_started_event_attributes)
    end
    assert_equal 0.11, event.timer_started_event_attributes.start_to_fire_timeout.to_f

    event = execute_workflow(TimerWorkflow, :sleep_workflow) do |handle|
      handle.result
      handle.fetch_history_events.find(&:timer_started_event_attributes)
    end
    assert_equal 0.12, event.timer_started_event_attributes.start_to_fire_timeout.to_f
    # TODO(cretz): Assert summary

    execute_workflow(TimerWorkflow, :sleep_stdlib_workflow_cancel) do |handle|
      assert_eventually { assert handle.fetch_history_events.any?(&:timer_started_event_attributes) }
      handle.cancel
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_instance_of Temporalio::Error::CanceledError, err.cause
    end

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

    err = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_workflow(TimerWorkflow, :timeout_stdlib) }
    assert_instance_of Temporalio::Error::ApplicationError, err.cause
    assert_equal 'execution expired', err.cause.message
    assert_equal 'Timeout::Error', err.cause.type

    err = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_workflow(TimerWorkflow, :timeout_workflow) }
    assert_instance_of Temporalio::Error::ApplicationError, err.cause
    assert_equal 'execution expired', err.cause.message
    assert_equal 'Timeout::Error', err.cause.type

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
        Timeout.timeout(nil) do
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
    assert_equal 'WorkerWorkflowTest::TaskFailureError1', err.cause.type

    # Fails workflow when configured on workflow, including inherited
    err = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_workflow(TaskFailureWorkflow, 2) }
    assert_equal 'two', err.cause.message
    assert_equal 'WorkerWorkflowTest::TaskFailureError2', err.cause.type
    err = assert_raises(Temporalio::Error::WorkflowFailedError) { execute_workflow(TaskFailureWorkflow, 4) }
    assert_equal 'four', err.cause.message
    assert_equal 'WorkerWorkflowTest::TaskFailureError4', err.cause.type

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
      sleep(0.01) unless Temporalio::Workflow::Unsafe.replaying?
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
      @bad_logger = Logger.new($stdout)
    end

    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_update
    def update
      Temporalio::Workflow.logger.info('some-log-1')
      Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled { @bad_logger.info('some-log-2') }
      sleep(0.01)
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
    assert_includes good_lines.first, ':workflow_type=>"LoggerWorkflow"'

    # Confirm there are two bad lines, and they don't have contextual info
    bad_lines = lines.select { |l| l.include?('some-log-2') }
    assert bad_lines.size >= 2
    refute_includes bad_lines.first, ':workflow_type=>"LoggerWorkflow"'

    # Confirm task failure logs
    out, = safe_capture_io do
      execute_workflow(LoggerWorkflow, logger: Logger.new($stdout)) do |handle|
        handle.signal(LoggerWorkflow.cause_task_failure)
        assert_eventually_task_fail(handle:)
      end
    end
    lines = out.split("\n").select { |l| l.include?(':workflow_type=>"LoggerWorkflow"') }
    assert(lines.any? { |l| l.include?('Failed activation') && l.include?(':workflow_type=>"LoggerWorkflow"') })
    assert(lines.any? { |l| l.include?('Some failure') && l.include?(':workflow_type=>"LoggerWorkflow"') })
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
          Temporalio::Workflow::Future.new { sleep(0.01) },
          Temporalio::Workflow::Future.new { 'done' }
        ).wait
        raise unless result == 'done'

        # Any of with exception
        begin
          Temporalio::Workflow::Future.any_of(
            Temporalio::Workflow::Future.new { sleep(0.01) },
            Temporalio::Workflow::Future.new { raise FutureWorkflowError }
          ).wait
          raise
        rescue FutureWorkflowError
          # Do nothing
        end

        # Try any of
        result = Temporalio::Workflow::Future.try_any_of(
          Temporalio::Workflow::Future.new { sleep(0.01) },
          Temporalio::Workflow::Future.new { 'done' }
        ).wait.wait
        raise unless result == 'done'

        # Try any of with exception
        try_any_of = Temporalio::Workflow::Future.try_any_of(
          Temporalio::Workflow::Future.new { sleep(0.01) },
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
    new_options = env.client.options.dup
    new_options.data_converter = Temporalio::Converters::DataConverter.new(payload_codec: Base64Codec.new)
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
    new_options = env.client.options.dup
    new_options.data_converter = Temporalio::Converters::DataConverter.new(
      failure_converter: Ractor.make_shareable(
        Temporalio::Converters::FailureConverter.new(encode_common_attributes: true)
      ),
      payload_codec: Base64Codec.new
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
      workflows: [DynamicWorkflow, NonDynamicWorkflow],
      # TODO(cretz): Ractor support not currently working
      workflow_executor: Temporalio::Worker::WorkflowExecutor::ThreadPool.default
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
      @queue = Queue.new
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
      @mutex = Mutex.new
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
    conn_opts = env.client.connection.options.dup
    conn_opts.runtime = runtime
    client_opts = env.client.options.dup
    client_opts.connection = Temporalio::Client::Connection.new(**conn_opts.to_h) # steep:ignore
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

  class FailWorkflowPayloadConverter < Temporalio::Converters::PayloadConverter
    def to_payload(value)
      if value == 'fail-on-this-result'
        raise Temporalio::Error::ApplicationError.new('Intentional error', type: 'IntentionalError')
      end

      Temporalio::Converters::PayloadConverter.default.to_payload(value)
    end

    def from_payload(payload)
      value = Temporalio::Converters::PayloadConverter.default.from_payload(payload)
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
    new_options = env.client.options.dup
    new_options.data_converter = Temporalio::Converters::DataConverter.new(
      payload_converter: Ractor.make_shareable(FailWorkflowPayloadConverter.new)
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

    class << self
      attr_accessor :initialized_count, :finalized_count

      def create_finalizer
        proc { @finalized_count += 1 }
      end
    end

    def initialize
      self.class.initialized_count += 1
      ObjectSpace.define_finalizer(self, self.class.create_finalizer)
    end

    def execute
      Temporalio::Workflow.wait_condition { false }
    end
  end

  def test_confirm_garbage_collect
    execute_workflow(ConfirmGarbageCollectWorkflow) do |handle|
      # Wait until it is started
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }
      # Confirm initialized but not finalized
      assert_equal 1, ConfirmGarbageCollectWorkflow.initialized_count
      assert_equal 0, ConfirmGarbageCollectWorkflow.finalized_count
    end

    # Now with worker shutdown, GC and confirm finalized
    assert_eventually do
      GC.start
      assert_equal 1, ConfirmGarbageCollectWorkflow.finalized_count
    end
  end

  # TODO(cretz): To test
  # * Common
  #   * Ractor with global state
  #   * Eager workflow start
  #   * Unawaited futures that have exceptions, need to log warning like Java does
  #   * Enhanced stack trace?
  #   * Separate abstract/interface demonstration
  #   * Replace worker client
  #   * Reset update randomness seed
  #   * Confirm thread pool does not leak, meaning thread/worker goes away after last workflow
  #   * Test workflow cancel causing other cancels at the same time but in different coroutines
  #   * 0-sleep timers vs nil timers
  #   * Interceptors
  # * Handler
  #   * Signal/update with start
  # * Activity
  #   * Local activity cancel (currently broken)
end
