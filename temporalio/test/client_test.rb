# frozen_string_literal: true

require 'async'
require 'temporalio/client'
require 'temporalio/testing'
require 'test'

class ClientTest < Test
  def test_version_number
    assert !Temporalio::VERSION.nil?
  end

  def start_simple_workflows
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

  def test_start_simple_workflows_threaded
    start_simple_workflows
  end

  def test_start_simple_workflows_async
    Sync do
      start_simple_workflows
    end
  end

  def test_lazy_connection
    assert env.client.connection.connected?
    client = Temporalio::Client.connect(env.client.connection.target_host, env.client.namespace, lazy_connect: true)
    refute client.connection.connected?
    env.with_kitchen_sink_worker(client) do |task_queue|
      result = client.execute_workflow(
        'kitchen_sink',
        { actions: [{ result: { value: 'done' } }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      assert_equal 'done', result
    end
    assert client.connection.connected?
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

  def test_search_attributes_and_memo
    # Make sure all keys on server
    key_text = Temporalio::SearchAttributes::Key.new('ruby-key-text',
                                                     Temporalio::SearchAttributes::IndexedValueType::TEXT)
    key_keyword = Temporalio::SearchAttributes::Key.new('ruby-key-keyword',
                                                        Temporalio::SearchAttributes::IndexedValueType::KEYWORD)
    key_integer = Temporalio::SearchAttributes::Key.new('ruby-key-integer',
                                                        Temporalio::SearchAttributes::IndexedValueType::INTEGER)
    key_float = Temporalio::SearchAttributes::Key.new('ruby-key-float',
                                                      Temporalio::SearchAttributes::IndexedValueType::FLOAT)
    key_boolean = Temporalio::SearchAttributes::Key.new('ruby-key-boolean',
                                                        Temporalio::SearchAttributes::IndexedValueType::BOOLEAN)
    key_time = Temporalio::SearchAttributes::Key.new('ruby-key-time',
                                                     Temporalio::SearchAttributes::IndexedValueType::TIME)
    key_keyword_list = Temporalio::SearchAttributes::Key.new(
      'ruby-key-keyword-list',
      Temporalio::SearchAttributes::IndexedValueType::KEYWORD_LIST
    )
    env.ensure_search_attribute_keys(key_text, key_keyword, key_integer, key_float, key_boolean, key_time,
                                     key_keyword_list)

    env.with_kitchen_sink_worker do |task_queue|
      # Remove precision because server doesn't store sub-second
      now = Time.at(Time.now.to_i)
      # Start a workflow with the different keys
      handle = env.client.start_workflow(
        'kitchen_sink',
        { actions: [{ result: { value: 'done' } }] },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:,
        search_attributes: Temporalio::SearchAttributes.new(
          {
            key_text => 'some text',
            key_keyword => 'some keyword',
            key_integer => 123,
            key_float => 45.67,
            key_boolean => true,
            key_time => now,
            key_keyword_list => ['some keyword list 1', 'some keyword list 2']
          }
        ),
        memo: { 'foo' => 'bar', 'baz' => %w[qux1 qux2] }
      )

      # Describe and check
      # TODO(cretz): Switch to high-level describe when written
      describe_resp = env.client.workflow_service.describe_workflow_execution(
        Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionRequest.new(
          namespace: env.client.namespace,
          execution: Temporalio::Api::Common::V1::WorkflowExecution.new(workflow_id: handle.id)
        )
      )
      assert_equal 'bar', env.client.data_converter.from_payload(
        describe_resp.workflow_execution_info.memo.fields['foo']
      )
      assert_equal %w[qux1 qux2], env.client.data_converter.from_payload(
        describe_resp.workflow_execution_info.memo.fields['baz']
      )
      attrs = Temporalio::SearchAttributes.from_proto(describe_resp.workflow_execution_info.search_attributes)
      assert_equal 'some text', attrs[key_text]
      assert_equal 'some keyword', attrs[key_keyword]
      assert_equal 123, attrs[key_integer]
      assert_equal 45.67, attrs[key_float]
      assert_equal true, attrs[key_boolean]
      assert_equal now, attrs[key_time]
      assert_equal ['some keyword list 1', 'some keyword list 2'], attrs[key_keyword_list]
    end
  end

  # TODO(cretz): Tests to write:
  # * Simple workflow with basic param and return type
  # * Workflow start delay works (just put a start delay and check its value, don't have to run)
  # * Workflow retry policy
  # * Workflow client interceptors all called properly
  # * Workflow search attributes and memo
  # * Workflow list (specific ID)
  # * Workflow counting
  # * Workflow cloud test
  # * Workflow recreate client with splatted options
  # * Start workflow other options
  # * CAN for get result following
  # * Workflow failure w/ details
  # * Get result not found
  # * Cancelling RPC of get result
  # * Query/Signal/Update obvious stuff
  # * Basic describe support
end
