# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

class WorkerWorkflowHandlerTest < Test
  class SimpleWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :my_signal_result

    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_signal
    def my_signal(arg)
      @my_signal_result = arg
    end

    workflow_query
    def my_query(arg)
      "Hello from query, #{arg}!"
    end

    workflow_update
    def my_update(arg)
      "Hello from update, #{arg}!"
    end
  end

  def test_simple
    execute_workflow(SimpleWorkflow) do |handle|
      handle.signal(SimpleWorkflow.my_signal, 'signal arg')
      assert_equal 'signal arg', handle.query(SimpleWorkflow.my_signal_result)
      assert_equal 'Hello from query, Temporal!', handle.query(SimpleWorkflow.my_query, 'Temporal')
      assert_equal 'Hello from update, Temporal!', handle.execute_update(SimpleWorkflow.my_update, 'Temporal')
    end
  end

  class ManualDefinitionWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :signal_values, :dynamic_signal_values

    def execute
      Temporalio::Workflow.query_handlers['my_query'] = Temporalio::Workflow::Definition::Query.new(
        name: 'my_query',
        to_invoke: proc { |arg1, arg2| [arg1, arg2] }
      )
      Temporalio::Workflow.update_handlers['my_update'] = Temporalio::Workflow::Definition::Update.new(
        name: 'my_update',
        to_invoke: proc { |arg1, arg2| [arg1, arg2] }
      )
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_signal
    def define_signal_handler
      # Make a new signal definition and expect it to process buffer
      Temporalio::Workflow.signal_handlers['my_signal'] = Temporalio::Workflow::Definition::Signal.new(
        name: 'my_signal',
        to_invoke: proc { |arg1, arg2| (@signal_values ||= []) << [arg1, arg2] }
      )
    end

    workflow_signal
    def define_dynamic_signal_handler
      Temporalio::Workflow.signal_handlers[nil] = Temporalio::Workflow::Definition::Signal.new(
        name: nil,
        to_invoke: proc { |arg1, *arg2| (@dynamic_signal_values ||= []) << [arg1, arg2] }
      )
    end
  end

  def test_manual_definition
    # Test regular
    execute_workflow(ManualDefinitionWorkflow) do |handle|
      # Send 3 signals, then send a signal to define handler
      handle.signal(:my_signal, 'sig1-arg1', 'sig1-arg2')
      handle.signal(:my_signal, 'sig2-arg1', 'sig2-arg2')
      handle.signal(ManualDefinitionWorkflow.define_signal_handler)

      # Confirm buffer processed
      expected = [%w[sig1-arg1 sig1-arg2], %w[sig2-arg1 sig2-arg2]]
      assert_equal expected, handle.query(ManualDefinitionWorkflow.signal_values)

      # Send a another and confirm
      handle.signal(:my_signal, 'sig3-arg1', 'sig3-arg2')
      expected << %w[sig3-arg1 sig3-arg2]
      assert_equal expected, handle.query(ManualDefinitionWorkflow.signal_values)

      # Send a couple for unknown signals and define dynamic
      assert_nil handle.query(ManualDefinitionWorkflow.dynamic_signal_values)
      handle.signal(:my_other_signal1, 'sig4-arg1', 'sig4-arg2')
      handle.signal(:my_other_signal2, 'sig5-arg1', 'sig5-arg2')
      handle.signal(ManualDefinitionWorkflow.define_dynamic_signal_handler)

      # Confirm buffer processed
      expected = [['my_other_signal1', %w[sig4-arg1 sig4-arg2]], ['my_other_signal2', %w[sig5-arg1 sig5-arg2]]]
      assert_equal expected, handle.query(ManualDefinitionWorkflow.dynamic_signal_values)

      # Send another and confirm
      handle.signal(:my_other_signal3, 'sig6-arg1', 'sig6-arg2')
      expected << ['my_other_signal3', %w[sig6-arg1 sig6-arg2]]
      assert_equal expected, handle.query(ManualDefinitionWorkflow.dynamic_signal_values)

      # Query and update
      assert_equal %w[q1 q2], handle.query('my_query', 'q1', 'q2')
      assert_equal %w[u1 u2], handle.execute_update('my_update', 'u1', 'u2')
    end
  end

  class CustomNameWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { @finish_with }
    end

    workflow_signal name: :custom_name1
    def my_signal(finish_with)
      @finish_with = finish_with
    end

    workflow_query name: 'custom_name2'
    def my_query(arg)
      "query result for: #{arg}"
    end

    workflow_update name: '5'
    def my_update(arg)
      "update result for: #{arg}"
    end
  end

  def test_custom_name
    execute_workflow(CustomNameWorkflow) do |handle|
      assert_equal 'query result for: arg1', handle.query(CustomNameWorkflow.my_query, 'arg1')
      assert_equal 'query result for: arg2', handle.query('custom_name2', 'arg2')
      assert_equal 'query result for: arg3', handle.query(:custom_name2, 'arg3')
      assert_equal 'update result for: arg4', handle.execute_update('5', 'arg4')
      handle.signal(:custom_name1, 'done')
      assert_equal 'done', handle.result
    end
  end

  class ArgumentsWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :signals

    def initialize
      @signals = []
    end

    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_signal
    def some_signal(single_arg)
      @signals << single_arg
    end

    workflow_query
    def some_query(single_arg)
      "query done: #{single_arg}"
    end

    workflow_update
    def some_update(single_arg)
      "update done: #{single_arg}"
    end

    workflow_signal
    def some_signal_with_defaults(single_arg = 'default signal arg')
      @signals << single_arg
    end

    workflow_query
    def some_query_with_defaults(single_arg = 'default query arg')
      "query done: #{single_arg}"
    end

    workflow_update
    def some_update_with_defaults(single_arg = 'default update arg')
      "update done: #{single_arg}"
    end
  end

  def test_arguments
    # Too few/many args
    execute_workflow(ArgumentsWorkflow) do |handle|
      # For signals, too few are just dropped, too many are trimmed
      handle.signal(ArgumentsWorkflow.some_signal)
      handle.signal(ArgumentsWorkflow.some_signal, 'one')
      handle.signal(ArgumentsWorkflow.some_signal, 'one', 'two')
      assert_equal %w[one one], handle.query(ArgumentsWorkflow.signals)

      # For query, too few fail query, too many are trimmed
      err = assert_raises(Temporalio::Error::WorkflowQueryFailedError) { handle.query(ArgumentsWorkflow.some_query) }
      assert_includes err.message, 'wrong number of required arguments for some_query (given 0, expected 1)'
      assert_equal 'query done: one', handle.query(ArgumentsWorkflow.some_query, 'one')
      assert_equal 'query done: one', handle.query(ArgumentsWorkflow.some_query, 'one', 'two')

      # For update, too few fail update, too many are trimmed
      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
        handle.execute_update(ArgumentsWorkflow.some_update)
      end
      assert_includes err.cause.message, 'wrong number of required arguments for some_update (given 0, expected 1)'
      assert_equal 'update done: one', handle.execute_update(ArgumentsWorkflow.some_update, 'one')
      assert_equal 'update done: one', handle.execute_update(ArgumentsWorkflow.some_update, 'one', 'two')
    end

    # Default parameters
    execute_workflow(ArgumentsWorkflow) do |handle|
      handle.signal(ArgumentsWorkflow.some_signal_with_defaults)
      handle.signal(ArgumentsWorkflow.some_signal_with_defaults, 'one')
      handle.signal(ArgumentsWorkflow.some_signal_with_defaults, 'one', 'two')
      assert_equal ['default signal arg', 'one', 'one'], handle.query(ArgumentsWorkflow.signals)

      assert_equal 'query done: default query arg', handle.query(ArgumentsWorkflow.some_query_with_defaults)
      assert_equal 'query done: one', handle.query(ArgumentsWorkflow.some_query_with_defaults, 'one')
      assert_equal 'query done: one', handle.query(ArgumentsWorkflow.some_query_with_defaults, 'one', 'two')

      assert_equal 'update done: default update arg', handle.execute_update(ArgumentsWorkflow.some_update_with_defaults)
      assert_equal 'update done: one', handle.execute_update(ArgumentsWorkflow.some_update_with_defaults, 'one')
      assert_equal 'update done: one', handle.execute_update(ArgumentsWorkflow.some_update_with_defaults, 'one', 'two')
    end
  end

  class DynamicWorkflow < Temporalio::Workflow::Definition
    def execute(manual_override)
      if manual_override
        Temporalio::Workflow.signal_handlers[nil] = Temporalio::Workflow::Definition::Signal.new(
          name: nil,
          raw_args: true,
          to_invoke: proc do |name, *args|
            arg_str = args.map do |v|
              Temporalio::Workflow.payload_converter.from_payload(v.payload)
            end.join(' -- ')
            @finish_with = "manual dyn signal: #{name} - #{arg_str}"
          end
        )
        Temporalio::Workflow.query_handlers[nil] = Temporalio::Workflow::Definition::Query.new(
          name: nil,
          raw_args: true,
          to_invoke: proc do |name, *args|
            arg_str = args.map { |v| Temporalio::Workflow.payload_converter.from_payload(v.payload) }.join(' -- ')
            "manual dyn query: #{name} - #{arg_str}"
          end
        )
        Temporalio::Workflow.update_handlers[nil] = Temporalio::Workflow::Definition::Update.new(
          name: nil,
          raw_args: true,
          to_invoke: proc do |name, *args|
            arg_str = args.map { |v| Temporalio::Workflow.payload_converter.from_payload(v.payload) }.join(' -- ')
            "manual dyn update: #{name} - #{arg_str}"
          end
        )
      end
      Temporalio::Workflow.wait_condition { @finish_with }
    end

    workflow_signal dynamic: true, raw_args: true
    def dynamic_signal(name, *args)
      arg_str = args.map { |v| Temporalio::Workflow.payload_converter.from_payload(v.payload) }.join(' -- ')
      @finish_with = "dyn signal: #{name} - #{arg_str}"
    end

    workflow_query dynamic: true, raw_args: true
    def dynamic_query(name, *args)
      arg_str = args.map { |v| Temporalio::Workflow.payload_converter.from_payload(v.payload) }.join(' -- ')
      "dyn query: #{name} - #{arg_str}"
    end

    workflow_update dynamic: true, raw_args: true
    def dynamic_update(name, *args)
      arg_str = args.map { |v| Temporalio::Workflow.payload_converter.from_payload(v.payload) }.join(' -- ')
      "dyn update: #{name} - #{arg_str}"
    end

    workflow_signal
    def non_dynamic_signal(*)
      # Do nothing
    end

    workflow_query
    def non_dynamic_query(*)
      'non-dynamic'
    end

    workflow_update
    def non_dynamic_update(*)
      'non-dynamic'
    end
  end

  def test_dynamic
    [true, false].each do |manual_override|
      prefix = manual_override ? 'manual ' : ''
      execute_workflow(DynamicWorkflow, manual_override) do |handle|
        # Non-dynamic
        handle.signal('non_dynamic_signal', 'signalarg1', 'signalarg2')
        assert_equal 'non-dynamic', handle.query('non_dynamic_query', 'queryarg1', 'queryarg2')
        assert_equal 'non-dynamic', handle.execute_update('non_dynamic_update', 'updatearg1', 'updatearg2')

        # Dynamic
        assert_equal "#{prefix}dyn query: non_dynamic_query_typo - queryarg1 -- queryarg2",
                     handle.query('non_dynamic_query_typo', 'queryarg1', 'queryarg2')
        assert_equal "#{prefix}dyn update: non_dynamic_update_typo - updatearg1 -- updatearg2",
                     handle.execute_update('non_dynamic_update_typo', 'updatearg1', 'updatearg2')
        handle.signal('non_dynamic_signal_typo', 'signalarg1', 'signalarg2')
        assert_equal "#{prefix}dyn signal: non_dynamic_signal_typo - signalarg1 -- signalarg2", handle.result
      end
    end
  end

  class UpdateValidatorWorkflow < Temporalio::Workflow::Definition
    def initialize
      Temporalio::Workflow.update_handlers['manual-update'] = Temporalio::Workflow::Definition::Update.new(
        name: 'manual-update',
        to_invoke: proc { |arg| "manual result for: #{arg}" },
        validator_to_invoke: proc { |arg| raise 'Bad manual arg' if arg == 'bad' }
      )
    end

    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_update
    def some_update(arg)
      "result for: #{arg}"
    end

    workflow_update_validator :some_update
    def some_update_validator(arg)
      raise 'Bad arg' if arg == 'bad'
    end

    workflow_update dynamic: true
    def some_dynamic_update(_name, arg)
      "dyn result for: #{arg}"
    end

    workflow_update_validator :some_dynamic_update
    def some_dynamic_update_validator(_name, arg)
      raise 'Bad dyn arg' if arg == 'bad'
    end
  end

  def test_update_validator
    execute_workflow(UpdateValidatorWorkflow) do |handle|
      assert_equal 'manual result for: good', handle.execute_update('manual-update', 'good')
      assert_equal 'result for: good', handle.execute_update(UpdateValidatorWorkflow.some_update, 'good')
      assert_equal 'dyn result for: good', handle.execute_update('some_update_typo', 'good')

      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
        handle.execute_update('manual-update', 'bad')
      end
      assert_equal 'Bad manual arg', err.cause.message
      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
        handle.execute_update(UpdateValidatorWorkflow.some_update, 'bad')
      end
      assert_equal 'Bad arg', err.cause.message
      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
        handle.execute_update('some_update_typo', 'bad')
      end
      assert_equal 'Bad dyn arg', err.cause.message
    end
  end

  class UnfinishedHandlersWorkflow < Temporalio::Workflow::Definition
    def initialize
      @finish = {}
    end

    def execute
      Temporalio::Workflow.wait_condition { @finish[:workflow] }
    end

    workflow_update
    def some_update1
      Temporalio::Workflow.wait_condition { @finish[:some_update1] }
    end

    workflow_update
    def some_update2
      Temporalio::Workflow.wait_condition { @finish[:some_update2] }
    end

    workflow_update unfinished_policy: Temporalio::Workflow::HandlerUnfinishedPolicy::ABANDON
    def some_update_abandon
      Temporalio::Workflow.wait_condition { @finish[:some_update_abandon] }
    end

    workflow_signal
    def some_signal1
      Temporalio::Workflow.wait_condition { @finish[:some_signal1] }
    end

    workflow_signal
    def some_signal2
      Temporalio::Workflow.wait_condition { @finish[:some_signal2] }
    end

    workflow_signal unfinished_policy: Temporalio::Workflow::HandlerUnfinishedPolicy::ABANDON
    def some_signal_abandon
      Temporalio::Workflow.wait_condition { @finish[:some_signal_abandon] }
    end

    workflow_query
    def all_handlers_finished?
      Temporalio::Workflow.all_handlers_finished?
    end

    workflow_signal
    def finish(thing)
      @finish[thing.to_sym] = true
    end
  end

  def test_unfinished_handlers_warn
    # Canceled workflow shows warning
    _, err = safe_capture_io do
      execute_workflow(UnfinishedHandlersWorkflow, logger: Logger.new($stdout)) do |handle|
        # Send updates and signals
        handle.start_update(UnfinishedHandlersWorkflow.some_update1,
                            wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED,
                            id: 'my-update-1')
        handle.start_update(UnfinishedHandlersWorkflow.some_update1,
                            wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED,
                            id: 'my-update-2')
        handle.start_update(UnfinishedHandlersWorkflow.some_update2,
                            wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED,
                            id: 'my-update-3')
        handle.start_update(UnfinishedHandlersWorkflow.some_update_abandon,
                            wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED,
                            id: 'my-update-4')
        handle.signal(UnfinishedHandlersWorkflow.some_signal1)
        handle.signal(UnfinishedHandlersWorkflow.some_signal1)
        handle.signal(UnfinishedHandlersWorkflow.some_signal2)
        handle.signal(UnfinishedHandlersWorkflow.some_signal_abandon)

        # Finish workflow
        handle.signal(UnfinishedHandlersWorkflow.finish, :workflow)
        handle.result
      end
    end
    lines = err.split("\n")

    # Check update
    update_lines = lines.select { |l| l.include?('update handlers are still running') }
    assert_equal 1, update_lines.size
    trailing_arr = update_lines.first[update_lines.first.rindex('[')..] # steep:ignore
    assert_equal [
      { 'name' => 'some_update1', 'id' => 'my-update-1' },
      { 'name' => 'some_update1', 'id' => 'my-update-2' },
      { 'name' => 'some_update2', 'id' => 'my-update-3' }
    ], JSON.parse(trailing_arr) # steep:ignore

    # Check update
    signal_lines = lines.select { |l| l.include?('signal handlers are still running') }
    assert_equal 1, signal_lines.size
    trailing_arr = signal_lines.first[signal_lines.first.rindex('[')..] # steep:ignore
    assert_equal [{ 'name' => 'some_signal1', 'count' => 2 }, { 'name' => 'some_signal2', 'count' => 1 }],
                 JSON.parse(trailing_arr) # steep:ignore
  end

  def test_unfinished_handlers_all_finished
    execute_workflow(UnfinishedHandlersWorkflow) do |handle|
      assert handle.query(UnfinishedHandlersWorkflow.all_handlers_finished?)
      handle.signal(UnfinishedHandlersWorkflow.some_signal1)
      refute handle.query(UnfinishedHandlersWorkflow.all_handlers_finished?)
      handle.signal(UnfinishedHandlersWorkflow.finish, :some_signal1)
      assert handle.query(UnfinishedHandlersWorkflow.all_handlers_finished?)
    end
  end

  class UpdateAndWorkflowCompletionWorkflow < Temporalio::Workflow::Definition
    def initialize
      @counter = 0
    end

    def execute(scenario, workflow_first)
      @workflow_finish = workflow_first
      @update_finish = true unless workflow_first
      case scenario.to_sym
      when :wait
        Temporalio::Workflow.wait_condition { @finish && @workflow_finish }
        "done: #{@counter += 1}"
      when :raise
        Temporalio::Workflow.wait_condition { @finish && @workflow_finish }
        raise Temporalio::Error::ApplicationError, "Intentional failure: #{@counter += 1}"
      else
        raise NotImplementedError
      end
    ensure
      @update_finish = true
    end

    workflow_update
    def some_update(scenario)
      case scenario.to_sym
      when :wait
        Temporalio::Workflow.wait_condition { @finish && @update_finish }
        "done: #{@counter += 1}"
      when :raise
        Temporalio::Workflow.wait_condition { @finish && @update_finish }
        raise Temporalio::Error::ApplicationError, "Intentional failure: #{@counter += 1}"
      else
        raise NotImplementedError
      end
    ensure
      @workflow_finish = true
    end

    workflow_signal
    def finish
      @finish = true
    end
  end

  def test_update_and_workflow_completion
    # Normal complete, workflow done first
    execute_workflow(UpdateAndWorkflowCompletionWorkflow, :wait, true) do |handle|
      update_handle = handle.start_update(
        UpdateAndWorkflowCompletionWorkflow.some_update, :wait,
        wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
      )
      handle.signal(UpdateAndWorkflowCompletionWorkflow.finish)
      assert_equal 'done: 1', handle.result
      assert_equal 'done: 2', update_handle.result
    end
    # Normal complete, update done first
    execute_workflow(UpdateAndWorkflowCompletionWorkflow, :wait, false) do |handle|
      update_handle = handle.start_update(
        UpdateAndWorkflowCompletionWorkflow.some_update, :wait,
        wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
      )
      handle.signal(UpdateAndWorkflowCompletionWorkflow.finish)
      assert_equal 'done: 2', handle.result
      assert_equal 'done: 1', update_handle.result
    end
    # Fail, workflow done first
    execute_workflow(UpdateAndWorkflowCompletionWorkflow, :raise, true) do |handle|
      update_handle = handle.start_update(
        UpdateAndWorkflowCompletionWorkflow.some_update, :raise,
        wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
      )
      handle.signal(UpdateAndWorkflowCompletionWorkflow.finish)
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_equal 'Intentional failure: 1', err.cause.message
      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) { update_handle.result }
      assert_equal 'Intentional failure: 2', err.cause.message
    end
    # Fail, update done first
    execute_workflow(UpdateAndWorkflowCompletionWorkflow, :raise, false) do |handle|
      update_handle = handle.start_update(
        UpdateAndWorkflowCompletionWorkflow.some_update, :raise,
        wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
      )
      handle.signal(UpdateAndWorkflowCompletionWorkflow.finish)
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_equal 'Intentional failure: 2', err.cause.message
      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) { update_handle.result }
      assert_equal 'Intentional failure: 1', err.cause.message
    end
  end

  class UpdateInfoWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.logger.info('In workflow')
      Temporalio::Workflow.wait_condition { @finish }
    end

    workflow_update
    def some_update
      Temporalio::Workflow.logger.info('In update')
      Temporalio::Workflow.wait_condition { @finish }
      Temporalio::Workflow.current_update_info.to_h
    end

    workflow_signal
    def finish
      @finish = true
    end
  end

  def test_update_info
    out, = safe_capture_io do
      execute_workflow(UpdateInfoWorkflow, logger: Logger.new($stdout)) do |handle|
        update1 = handle.start_update(
          UpdateInfoWorkflow.some_update,
          wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED,
          id: 'update-1'
        )
        update2 = handle.start_update(
          UpdateInfoWorkflow.some_update,
          wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED,
          id: 'update-2'
        )
        handle.signal(UpdateInfoWorkflow.finish)
        handle.result
        assert_equal({ 'id' => 'update-1', 'name' => 'some_update' }, update1.result)
        assert_equal({ 'id' => 'update-2', 'name' => 'some_update' }, update2.result)
      end
    end
    # Confirm logs for workflow and updates
    lines = out.split("\n")
    assert(lines.any? do |l|
      l.include?('In workflow') && l.include?('workflow_type') &&
        l.include?('"UpdateInfoWorkflow"') && !l.include?('update_id')
    end)
    assert(lines.any? do |l|
      l.include?('In update') && l.include?('workflow_type') &&
        l.include?('"UpdateInfoWorkflow"') && l.include?('update_id') && l.include?('"update-1"')
    end)
    assert(lines.any? do |l|
      l.include?('In update') && l.include?('workflow_type') &&
      l.include?('"UpdateInfoWorkflow"') && l.include?('update_id') && l.include?('"update-2"')
    end)
  end

  class RetryStartUpdateWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_update
    def some_update
      'done'
    end
  end

  def test_retry_start_update
    # This test confirms that the UpdateWorkflowExecution call occurs multiple times if it hasn't reached accepted. We
    # check this via metrics.
    buffer = Temporalio::Runtime::MetricBuffer.new(10_000)
    Temporalio::Testing::WorkflowEnvironment.start_local(
      runtime: Temporalio::Runtime.new(
        telemetry: Temporalio::Runtime::TelemetryOptions.new(metrics: Temporalio::Runtime::MetricsOptions.new(buffer:))
      ),
      logger: Logger.new($stdout),
      # Reduce poll interval so it tries again sooner
      dev_server_extra_args: ['--dynamic-config-value', 'history.longPollExpirationInterval="3s"']
    ) do |local_env|
      # Start workflow, then issue update without a running worker
      task_queue = "tq-#{SecureRandom.uuid}"
      handle = local_env.client.start_workflow(RetryStartUpdateWorkflow, id: "wf-#{SecureRandom.uuid}", task_queue:)

      # Wait for update in background
      queue = Queue.new
      run_in_background { queue << handle.execute_update(RetryStartUpdateWorkflow.some_update) }

      # Wait for there to be at least 2 update requests
      update_requests = 0
      assert_eventually do
        buffer.retrieve_updates.each do |update|
          if update.metric.name == 'temporal_long_request' &&
             update.attributes['operation'] == 'UpdateWorkflowExecution'
            update_requests += update.value # steep:ignore
          end
        end
        assert update_requests >= 2
      end

      # Now run the worker that will let the update be processed
      Temporalio::Worker.new(client: local_env.client, task_queue:, workflows: [RetryStartUpdateWorkflow]).run do
        assert_equal 'done', queue.pop(timeout: 5)
      end
    end
  end

  class UpdateWithStartWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :counter

    def initialize
      @counter = 0
    end

    def execute(initial_increment)
      @counter += initial_increment
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_update
    def increment_counter(value)
      @counter += value
    end

    workflow_update
    def fail
      raise Temporalio::Error::ApplicationError, 'Intentional failure'
    end

    workflow_update
    def start_waiting
      Temporalio::Workflow.wait_condition { @finish_waiting }
    end

    workflow_update
    def finish_waiting
      @finish_waiting = true
    end
  end

  def test_update_with_start_simple
    # Run worker
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [UpdateWithStartWorkflow]
    )
    worker.run do
      # Newly started
      id = "wf-#{SecureRandom.uuid}"
      start_workflow_operation = Temporalio::Client::WithStartWorkflowOperation.new(
        UpdateWithStartWorkflow, 123,
        id:, task_queue: worker.task_queue, id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::FAIL
      )
      # Run and confirm result of update is pre-workflow-execute
      assert_equal 456, env.client.execute_update_with_start_workflow(
        UpdateWithStartWorkflow.increment_counter, 456, start_workflow_operation:
      )
      # Confirm query is total
      handle = start_workflow_operation.workflow_handle
      assert_equal 579, handle.query(UpdateWithStartWorkflow.counter)

      # Update with start 5 more times
      5.times do
        env.client.execute_update_with_start_workflow(
          UpdateWithStartWorkflow.increment_counter, 2,
          start_workflow_operation: Temporalio::Client::WithStartWorkflowOperation.new(
            UpdateWithStartWorkflow, 10_000,
            id:, task_queue: worker.task_queue, id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::USE_EXISTING
          )
        )
      end
      # Confirm 10 (i.e. 5 * 2) was added
      assert_equal 589, handle.query(UpdateWithStartWorkflow.counter)

      # Confirm we get already-exists error on start and on call if we set fail existing
      start_workflow_operation = Temporalio::Client::WithStartWorkflowOperation.new(
        UpdateWithStartWorkflow, 123,
        id:, task_queue: worker.task_queue, id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::FAIL
      )
      assert_raises(Temporalio::Error::WorkflowAlreadyStartedError) do
        env.client.execute_update_with_start_workflow(
          UpdateWithStartWorkflow.increment_counter, 456, start_workflow_operation:
        )
      end
      assert_raises(Temporalio::Error::WorkflowAlreadyStartedError) do
        start_workflow_operation.workflow_handle
      end
    end
  end

  def test_update_with_start_update_failure
    # Run worker
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [UpdateWithStartWorkflow]
    )
    worker.run do
      # Update failed but workflow started
      id = "wf-#{SecureRandom.uuid}"
      start_workflow_operation = Temporalio::Client::WithStartWorkflowOperation.new(
        UpdateWithStartWorkflow, 123,
        id:, task_queue: worker.task_queue, id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::FAIL
      )
      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
        env.client.execute_update_with_start_workflow(UpdateWithStartWorkflow.fail, 456, start_workflow_operation:)
      end
      assert_instance_of Temporalio::Error::ApplicationError, err.cause
      assert_equal 'Intentional failure', err.cause.message
      assert_equal 123, start_workflow_operation.workflow_handle.query(UpdateWithStartWorkflow.counter)
    end
  end

  def test_update_with_start_cancel
    # Run worker
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [UpdateWithStartWorkflow]
    )
    worker.run do
      # Run update in background to start with cancellation
      cancellation, cancel_proc = Temporalio::Cancellation.new
      id = "wf-#{SecureRandom.uuid}"
      start_workflow_operation = Temporalio::Client::WithStartWorkflowOperation.new(
        UpdateWithStartWorkflow, 123,
        id:, task_queue: worker.task_queue, id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::FAIL
      )
      background_exc_queue = Queue.new
      run_in_background do
        env.client.execute_update_with_start_workflow(
          UpdateWithStartWorkflow.start_waiting, 456,
          start_workflow_operation:, rpc_options: Temporalio::Client::RPCOptions.new(cancellation:)
        )
      rescue Temporalio::Error => e
        background_exc_queue << e
      end

      # Wait until workflow ID exists
      assert_eventually do
        env.client.workflow_handle(id).describe
      rescue Temporalio::Error::RPCError => e
        flunk e.full_message
      end

      # Now cancel token and confirm it is a proper cancellation
      cancel_proc.call
      assert_instance_of Temporalio::Error::WorkflowUpdateRPCTimeoutOrCanceledError, background_exc_queue.pop
    end
  end

  def test_update_with_start_start_fail
    # Run worker
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [UpdateWithStartWorkflow]
    )
    worker.run do
      id = "wf-#{SecureRandom.uuid}"
      # Start the workflow
      env.client.start_workflow(UpdateWithStartWorkflow, 123, id:, task_queue: worker.task_queue)
      # Try to update-with-start on already existing, confirm call and getting handle fail
      start_workflow_operation = Temporalio::Client::WithStartWorkflowOperation.new(
        UpdateWithStartWorkflow, 123,
        id:, task_queue: worker.task_queue, id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::FAIL
      )
      assert_raises(Temporalio::Error::WorkflowAlreadyStartedError) do
        env.client.start_update_with_start_workflow(
          UpdateWithStartWorkflow.increment_counter, 456,
          wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED, start_workflow_operation:
        )
      end
      assert_raises(Temporalio::Error::WorkflowAlreadyStartedError) do
        start_workflow_operation.workflow_handle
      end
    end
  end

  def test_update_with_start_user_metadata
    # Run worker
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [UpdateWithStartWorkflow]
    )
    worker.run do
      id = "wf-#{SecureRandom.uuid}"
      start_workflow_operation = Temporalio::Client::WithStartWorkflowOperation.new(
        UpdateWithStartWorkflow, 123,
        id:, task_queue: worker.task_queue,
        static_summary: 'my-summary', static_details: 'my-details',
        id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::FAIL
      )
      # Run and confirm metadata present
      env.client.start_update_with_start_workflow(
        UpdateWithStartWorkflow.increment_counter, 456,
        wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED, start_workflow_operation:
      )
      desc = start_workflow_operation.workflow_handle.describe
      assert_equal 'my-summary', desc.static_summary
      assert_equal 'my-details', desc.static_details
    end
  end

  class SignalWithStartWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :events

    def initialize
      @events = []
    end

    def execute(event)
      @events << event
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_signal
    def add_event(event)
      @events << event
    end
  end

  def test_signal_with_start
    # Run worker
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [SignalWithStartWorkflow]
    )
    worker.run do
      # Newly started
      id = "wf-#{SecureRandom.uuid}"
      start_workflow_operation = Temporalio::Client::WithStartWorkflowOperation.new(
        SignalWithStartWorkflow, 'workflow-start',
        id:, task_queue: worker.task_queue
      )
      handle = env.client.signal_with_start_workflow(
        SignalWithStartWorkflow.add_event, 'signal', start_workflow_operation:
      )
      # Confirm same handle
      assert_same handle, start_workflow_operation.workflow_handle
      # Confirm signal event came first
      assert_equal %w[signal workflow-start], handle.query(SignalWithStartWorkflow.events)

      # Signal with start 3 more times
      3.times do |i|
        env.client.signal_with_start_workflow(
          SignalWithStartWorkflow.add_event, "signal-#{i}",
          start_workflow_operation: Temporalio::Client::WithStartWorkflowOperation.new(
            SignalWithStartWorkflow, 'not-used',
            id:, task_queue: worker.task_queue
          )
        )
      end
      # Confirm events
      assert_equal %w[signal workflow-start signal-0 signal-1 signal-2], handle.query(SignalWithStartWorkflow.events)
    end
  end

  def test_signal_with_start_user_metadata
    # Run worker
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [SignalWithStartWorkflow]
    )
    worker.run do
      # Newly started
      id = "wf-#{SecureRandom.uuid}"
      start_workflow_operation = Temporalio::Client::WithStartWorkflowOperation.new(
        SignalWithStartWorkflow, 'workflow-start',
        id:, task_queue: worker.task_queue,
        static_summary: 'my-summary', static_details: 'my-details'
      )
      handle = env.client.signal_with_start_workflow(
        SignalWithStartWorkflow.add_event, 'signal', start_workflow_operation:
      )
      desc = handle.describe
      assert_equal 'my-summary', desc.static_summary
      assert_equal 'my-details', desc.static_details
    end
  end

  class HandlerNameReuseWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { @signal }
    end

    workflow_signal name: :foo
    def foo_signal(value)
      @signal = value
    end

    workflow_query name: :foo
    def foo_query
      'query-done'
    end

    workflow_update name: :foo
    def foo_update
      'update-done'
    end
  end

  def test_handler_name_reuse
    execute_workflow(HandlerNameReuseWorkflow) do |handle|
      assert_equal 'query-done', handle.query(HandlerNameReuseWorkflow.foo_query)
      assert_equal 'update-done', handle.execute_update(HandlerNameReuseWorkflow.foo_update)
      handle.signal(HandlerNameReuseWorkflow.foo_signal, 'signal-done')
      assert_equal 'signal-done', handle.result
    end
  end
end
