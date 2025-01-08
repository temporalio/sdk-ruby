# frozen_string_literal: true

require 'async'
require 'temporalio/client'
require 'temporalio/testing'
require 'test'

class ClientWorkflowTest < Test
  also_run_all_tests_in_fiber

  def test_start_simple
    # Create ephemeral test server
    env.with_kitchen_sink_worker do |task_queue|
      # Start 5 workflows
      handles = 5.times.map do |i|
        env.client.start_workflow(
          'kitchen_sink',
          { actions: [{ result: { value: "result-#{i}" } }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue:
        )
      end
      # Check all results
      results = handles.map(&:result)
      assert_equal %w[result-0 result-1 result-2 result-3 result-4], results
    end
  end

  def test_workflow_exists
    env.with_kitchen_sink_worker do |task_queue|
      # Create a workflow that hangs
      handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ action_signal: 'complete' }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )

      # Confirm next one fails as already started
      err = assert_raises(Temporalio::Error::WorkflowAlreadyStartedError) do
        env.client.start_workflow(
          'kitchen_sink',
          { actions: [{ action_signal: 'complete' }] },
          id: handle.id,
          task_queue:
        )
      end
      assert_equal handle.id, err.workflow_id
      assert_equal 'kitchen_sink', err.workflow_type
      assert_equal handle.result_run_id, err.run_id

      # But that we can start another with an ID conflict policy that terminates
      # it
      new_handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ result: { value: 'done' } }] },
        id: handle.id,
        task_queue:,
        id_conflict_policy: Temporalio::WorkflowIDConflictPolicy::TERMINATE_EXISTING
      )
      assert_equal handle.id, new_handle.id
      refute_equal handle.result_run_id, new_handle.result_run_id

      # Now confirm complete and another fails w/ on duplicate failed only
      assert_equal 'done', new_handle.result
      assert_raises(Temporalio::Error::WorkflowAlreadyStartedError) do
        env.client.start_workflow(
          'kitchen_sink',
          { actions: [{ result: { value: 'done' } }] },
          id: handle.id,
          task_queue:,
          id_reuse_policy: Temporalio::WorkflowIDReusePolicy::ALLOW_DUPLICATE_FAILED_ONLY
        )
      end
    end
  end

  def test_lazy_connect
    client = Temporalio::Client.connect(
      env.client.connection.target_host,
      env.client.namespace,
      lazy_connect: true
    )
    # Not connected until we do something
    refute client.connection.connected?
    client.start_workflow(
      'does-not-exist',
      id: "wf-#{SecureRandom.uuid}",
      task_queue: "tq-#{SecureRandom.uuid}"
    )
    assert client.connection.connected?
  end

  def test_describe
    # Make sure all keys on server
    env.ensure_common_search_attribute_keys

    env.with_kitchen_sink_worker do |task_queue|
      # Remove precision because server doesn't store sub-second
      now = Time.at(Time.now.to_i)
      # Start a workflow with the different SA/memo
      handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ result: { value: 'done' } }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:,
        search_attributes: Temporalio::SearchAttributes.new(
          {
            ATTR_KEY_TEXT => 'some text',
            ATTR_KEY_KEYWORD => 'some keyword',
            ATTR_KEY_INTEGER => 123,
            ATTR_KEY_FLOAT => 45.67,
            ATTR_KEY_BOOLEAN => true,
            ATTR_KEY_TIME => now,
            ATTR_KEY_KEYWORD_LIST => ['some keyword list 1', 'some keyword list 2']
          }
        ),
        memo: { 'foo' => 'bar', 'baz' => %w[qux1 qux2] }
      )
      # Wait until done
      handle.result

      # Describe and check
      desc = handle.describe
      assert_instance_of Time, desc.close_time
      assert_instance_of Time, desc.execution_time
      assert_instance_of Integer, desc.history_length
      assert_equal handle.id, desc.id
      assert_equal({ 'foo' => 'bar', 'baz' => %w[qux1 qux2] }, desc.memo)
      assert_nil desc.parent_id
      assert_nil desc.parent_run_id
      assert_equal handle.result_run_id, desc.run_id
      assert_instance_of Time, desc.start_time
      assert_equal Temporalio::Client::WorkflowExecutionStatus::COMPLETED, desc.status
      attrs = desc.search_attributes #: Temporalio::SearchAttributes
      assert_equal 'some text', attrs[ATTR_KEY_TEXT]
      assert_equal 'some keyword', attrs[ATTR_KEY_KEYWORD]
      assert_equal 123, attrs[ATTR_KEY_INTEGER]
      assert_equal 45.67, attrs[ATTR_KEY_FLOAT]
      assert_equal true, attrs[ATTR_KEY_BOOLEAN]
      assert_equal now, attrs[ATTR_KEY_TIME]
      assert_equal ['some keyword list 1', 'some keyword list 2'], attrs[ATTR_KEY_KEYWORD_LIST]
      assert_equal task_queue, desc.task_queue
      assert_equal 'kitchen_sink', desc.workflow_type
    end
  end

  def test_start_delay
    env.with_kitchen_sink_worker do |task_queue|
      handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ result: { value: { donekey: 'doneval' } } }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:,
        start_delay: 0.01
      )
      assert_equal({ 'donekey' => 'doneval' }, handle.result)
      assert_equal 0.01,
                   handle
                     .fetch_history_events
                     .first
                     .workflow_execution_started_event_attributes
                     .first_workflow_task_backoff
                     .to_f
    end
  end

  def test_failure
    env.with_kitchen_sink_worker do |task_queue|
      # Simple error
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        env.client.execute_workflow(
          'kitchen_sink',
          { actions: [{ error: { message: 'some error', type: 'error-type', details: { foo: 'bar', baz: 123.45 } } }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue:
        )
      end
      assert_instance_of Temporalio::Error::ApplicationError, err.cause
      assert_equal 'some error', err.cause.message
      assert_equal 'error-type', err.cause.type
      refute err.cause.non_retryable
      assert_equal [{ 'foo' => 'bar', 'baz' => 123.45 }], err.cause.details

      # Activity does not exist, for checking causes
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        env.client.execute_workflow(
          'kitchen_sink',
          { actions: [{ execute_activity: { name: 'does-not-exist' } }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue:
        )
      end
      assert_instance_of Temporalio::Error::ActivityError, err.cause
      assert_instance_of Temporalio::Error::ApplicationError, err.cause.cause
      assert_includes err.cause.cause.message, 'does-not-exist'
    end
  end

  def test_retry_policy
    env.with_kitchen_sink_worker do |task_queue|
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        env.client.execute_workflow(
          'kitchen_sink',
          { actions: [{ error: { attempt: true } }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue:,
          retry_policy: Temporalio::RetryPolicy.new(
            initial_interval: 0.01,
            max_attempts: 2
          )
        )
      end
      assert_instance_of Temporalio::Error::ApplicationError, err.cause
      assert_equal 'attempt 2', err.cause.message
    end
  end

  def test_list_and_count
    # Make sure all keys on server
    env.ensure_common_search_attribute_keys

    # Start 5 workflows, 3 that complete and 2 that don't, and with different
    # SAs for odd ones vs even
    text_val = "test-list-#{SecureRandom.uuid}"
    env.with_kitchen_sink_worker do |task_queue|
      handles = 5.times.map do |i|
        env.client.start_workflow(
          'kitchen_sink',
          if i <= 2
            { actions: [{ result: { value: 'done' } }] }
          else
            { action_signal: 'wait' }
          end,
          id: "wf-#{SecureRandom.uuid}-#{i}",
          task_queue:,
          search_attributes: Temporalio::SearchAttributes.new(
            {
              ATTR_KEY_TEXT => text_val,
              ATTR_KEY_KEYWORD => i.even? ? 'even' : 'odd'
            }
          )
        )
      end

      # Make sure all 5 come back in list
      assert_eventually do
        wfs = env.client.list_workflows("`#{ATTR_KEY_TEXT.name}` = '#{text_val}'").to_a
        assert_equal 5, wfs.size
        # Check each item is present too
        assert_equal handles.map(&:id).sort, wfs.map(&:id).sort
        # Check the first has search attr
        assert_equal text_val, wfs.first&.search_attributes&.[](ATTR_KEY_TEXT)
      end

      # Query for just the odd ones and make sure it's two
      assert_eventually do
        wfs = env.client.list_workflows("`#{ATTR_KEY_TEXT.name}` = '#{text_val}' AND " \
                                        "`#{ATTR_KEY_KEYWORD.name}` = 'odd'").to_a
        assert_equal 2, wfs.size
      end

      # Normal count
      assert_eventually do
        count = env.client.count_workflows("`#{ATTR_KEY_TEXT.name}` = '#{text_val}'")
        assert_equal 5, count.count
        assert_empty count.groups
      end

      # Count with group by making sure eventually first 3 are complete
      assert_eventually do
        count = env.client.count_workflows("`#{ATTR_KEY_TEXT.name}` = '#{text_val}' GROUP BY ExecutionStatus")
        assert_equal 5, count.count
        groups = count.groups.sort_by(&:count)
        # 2 running, 3 completed
        assert_equal 2, groups[0].count
        assert_equal ['Running'], groups[0].group_values
        assert_equal 3, groups[1].count
        assert_equal ['Completed'], groups[1].group_values
      end
    end
  end

  def test_continue_as_new
    env.with_kitchen_sink_worker do |task_queue|
      handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ continue_as_new: { while_above_zero: 1, result: 'done' } }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      assert_equal 'done', handle.result

      # Confirm what happens if we do not follow runs on the handle
      assert_raises(Temporalio::Error::WorkflowContinuedAsNewError) do
        handle.result(follow_runs: false)
      end
    end
  end

  def test_not_found
    handle = env.client.workflow_handle('does-not-exist')
    err = assert_raises(Temporalio::Error::RPCError) do
      handle.describe
    end
    assert_equal Temporalio::Error::RPCError::Code::NOT_FOUND, err.code
    err = assert_raises(Temporalio::Error::RPCError) do
      handle.result
    end
    assert_equal Temporalio::Error::RPCError::Code::NOT_FOUND, err.code
  end

  def test_config_change
    env.with_kitchen_sink_worker do |task_queue|
      # Regular query works
      handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ query_handler: { name: 'some query' } }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      handle.result
      assert_equal 'some query arg', handle.query('some query', 'some query arg')

      # Now demonstrate simple configuration change w/ default reject condition
      new_options = env.client.options.dup
      new_options.default_workflow_query_reject_condition = Temporalio::Client::WorkflowQueryRejectCondition::NOT_OPEN
      new_client = Temporalio::Client.new(**new_options.to_h) # steep:ignore
      err = assert_raises(Temporalio::Error::WorkflowQueryRejectedError) do
        new_client.workflow_handle(handle.id).query('some query', 'some query arg')
      end
      assert_equal Temporalio::Client::WorkflowExecutionStatus::COMPLETED, err.status
    end
  end

  def test_signal
    env.with_kitchen_sink_worker do |task_queue|
      handle = env.client.start_workflow(
        'kitchen_sink',
        { action_signal: 'some signal' },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      handle.signal('some signal', { result: { value: 'some signal arg' } })
      assert_equal 'some signal arg', handle.result
    end
  end

  def test_query
    env.with_kitchen_sink_worker do |task_queue|
      handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ query_handler: { name: 'some query' } }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      handle.result
      assert_equal 'some query arg', handle.query('some query', 'some query arg')

      # Check query not present
      err = assert_raises(Temporalio::Error::WorkflowQueryFailedError) do
        handle.query('unknown query')
      end
      assert_includes err.message, 'unknown query'

      # Query reject condition
      err = assert_raises(Temporalio::Error::WorkflowQueryRejectedError) do
        handle.query('some query', 'some query arg',
                     reject_condition: Temporalio::Client::WorkflowQueryRejectCondition::NOT_OPEN)
      end
      assert_equal Temporalio::Client::WorkflowExecutionStatus::COMPLETED, err.status
    end
  end

  def test_update
    env.with_kitchen_sink_worker do |task_queue|
      handle = env.client.start_workflow(
        'kitchen_sink',
        {
          actions: [
            { update_handler: { name: 'update-success' } },
            { update_handler: { name: 'update-fail', error: 'update failed' } },
            { update_handler: { name: 'update-wait', wait_for_signal: 'finish-update' } }
          ],
          action_signal: 'wait'
        },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )

      # Simple update success
      assert_equal 'update-result', handle.execute_update('update-success', 'update-result')

      # Simple update failure
      err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) do
        handle.execute_update('update-fail', 'update-result')
      end
      assert_instance_of Temporalio::Error::ApplicationError, err.cause
      assert_equal 'update failed', err.cause.message

      # Immediate complete update success via start+result
      update_handle = handle.start_update(
        'update-success',
        'update-result',
        # TODO(cretz): Can make this ACCEPTED once https://github.com/temporalio/temporal/pull/6477 released
        wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::COMPLETED
      )
      assert update_handle.result_obtained?
      assert_equal 'update-result', update_handle.result

      # Async complete
      update_handle = handle.start_update(
        'update-wait',
        'update-result',
        wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
      )
      refute update_handle.result_obtained?
      handle.signal('finish-update', 'update-result-from-signal')
      assert_equal 'update-result-from-signal', update_handle.result
      assert update_handle.result_obtained?
    end
  end

  def test_cancel
    env.with_kitchen_sink_worker do |task_queue|
      handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ sleep: { millis: 50_000 } }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      handle.cancel
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        handle.result
      end
      assert_instance_of Temporalio::Error::CanceledError, err.cause
    end
  end

  def test_terminate
    env.with_kitchen_sink_worker do |task_queue|
      handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ sleep: { millis: 50_000 } }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      handle.terminate('some reason', details: ['some details'])
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        handle.result
      end
      assert_instance_of Temporalio::Error::TerminatedError, err.cause
      assert_equal 'some reason', err.cause.message
      assert_equal ['some details'], err.cause.details
    end
  end

  def test_rpc_cancellation
    # Start a workflow, create cancellation, cancel after 500ms in background,
    # wait on complete
    env.with_kitchen_sink_worker do |task_queue|
      handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ sleep: { millis: 50_000 } }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      cancellation, cancel_proc = Temporalio::Cancellation.new
      run_in_background do
        sleep(0.5)
        cancel_proc.call
      end
      err = assert_raises(Temporalio::Error::CanceledError) do
        handle.result(rpc_options: Temporalio::Client::RPCOptions.new(cancellation:))
      end
      assert_equal 'User canceled', err.message
    end
  end

  # TODO(cretz): Tests to write:
  # * Workflow cloud test
  # * Signal/update with start
end
