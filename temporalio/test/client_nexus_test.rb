# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/error'
require 'temporalio/testing'
require 'test'

class ClientNexusTest < Test
  def test_nexus_standalone_sync_execute_operation
    with_nexus_client do |nexus_client, endpoint|
      result = nexus_client.execute_operation('echo', 'success', id: SecureRandom.uuid,
                                                                 schedule_to_close_timeout: 30)
      assert_equal 'success', result
    end
  end

  def test_nexus_standalone_sync_start_and_result
    with_nexus_client do |nexus_client, endpoint|
      op_id = SecureRandom.uuid
      handle = nexus_client.start_operation('echo', 'success', id: op_id, schedule_to_close_timeout: 30)

      assert_instance_of Temporalio::Client::NexusOperationHandle, handle
      assert_equal op_id, handle.operation_id
      refute_nil handle.run_id

      result = handle.result
      assert_equal 'success', result
    end
  end

  def test_nexus_standalone_async_operation
    with_nexus_client do |nexus_client, endpoint|
      op_id = SecureRandom.uuid
      handle = nexus_client.start_operation('workflow-operation', { 'action' => 'success' },
                                            id: op_id, schedule_to_close_timeout: 30)

      assert_instance_of Temporalio::Client::NexusOperationHandle, handle
      assert_equal op_id, handle.operation_id
      refute_nil handle.run_id

      result = handle.result
      assert_instance_of Hash, result
      assert_equal 'success', result['result']
    end
  end

  def test_nexus_standalone_cancel_operation
    with_nexus_client do |nexus_client, endpoint|
      op_id = SecureRandom.uuid
      handle = nexus_client.start_operation('workflow-operation', { 'action' => 'wait-for-cancel' },
                                            id: op_id, schedule_to_close_timeout: 30)
      assert_equal op_id, handle.operation_id

      # Wait for the operation to be running
      assert_eventually do
        desc = handle.describe
        refute_nil desc.info
        assert_equal op_id, desc.info.operation_id
        assert_equal 'test-service', desc.info.service
        assert_equal 'workflow-operation', desc.info.operation
        assert_equal endpoint, desc.info.endpoint
      end

      handle.cancel(reason: 'test cancel')

      # Waiting for result should raise with cancellation cause
      err = assert_raises(Temporalio::Error::NexusOperationFailedError) { handle.result }
      assert_equal op_id, err.operation_id
      assert_instance_of Temporalio::Error::CanceledError, err.cause
    end
  end

  def test_nexus_standalone_terminate_operation
    with_nexus_client do |nexus_client, endpoint|
      op_id = SecureRandom.uuid
      handle = nexus_client.start_operation('workflow-operation', { 'action' => 'wait-for-cancel' },
                                            id: op_id, schedule_to_close_timeout: 30)
      assert_equal op_id, handle.operation_id

      assert_eventually do
        desc = handle.describe
        refute_nil desc.info
      end

      handle.terminate(reason: 'test terminate')
    end
  end

  def test_nexus_standalone_describe_operation
    with_nexus_client do |nexus_client, endpoint|
      op_id = SecureRandom.uuid
      handle = nexus_client.start_operation('workflow-operation', { 'action' => 'success' },
                                            id: op_id, schedule_to_close_timeout: 30)

      desc = handle.describe
      refute_nil desc
      refute_nil desc.info
      assert_equal op_id, desc.info.operation_id
      assert_equal endpoint, desc.info.endpoint
      assert_equal 'test-service', desc.info.service
      assert_equal 'workflow-operation', desc.info.operation
      refute_nil desc.run_id
    end
  end

  def test_nexus_standalone_list_operations
    with_nexus_client do |nexus_client, _endpoint|
      op_id = SecureRandom.uuid
      nexus_client.start_operation('echo', 'success', id: op_id, schedule_to_close_timeout: 30)

      ops = env.client.list_nexus_operations.to_a
      refute_empty ops

      # Find our operation in the list
      our_op = ops.find { |op| op.operation_id == op_id }
      refute_nil our_op, "Expected to find operation #{op_id} in list"
      assert_equal 'test-service', our_op.service
      assert_equal 'echo', our_op.operation
    end
  end

  def test_nexus_standalone_count_operations
    with_nexus_client do |nexus_client, _endpoint|
      nexus_client.start_operation('echo', 'success', id: SecureRandom.uuid, schedule_to_close_timeout: 30)

      count = env.client.count_nexus_operations
      assert_instance_of Temporalio::Client::NexusOperationExecutionCount, count
      assert_operator count.count, :>=, 1
      assert_instance_of Array, count.groups
    end
  end

  def test_nexus_standalone_operation_handle_factory
    with_nexus_client do |nexus_client, endpoint|
      op_id = SecureRandom.uuid
      original = nexus_client.start_operation('workflow-operation', { 'action' => 'success' },
                                              id: op_id, schedule_to_close_timeout: 30)

      # Get a new handle via the factory method
      handle = env.client.nexus_operation_handle(original.operation_id)
      assert_instance_of Temporalio::Client::NexusOperationHandle, handle
      assert_equal op_id, handle.operation_id
      assert_nil handle.run_id

      # Describe should work and return the same operation
      desc = handle.describe
      refute_nil desc.info
      assert_equal op_id, desc.info.operation_id
      assert_equal endpoint, desc.info.endpoint
      assert_equal 'test-service', desc.info.service
    end
  end

  def test_nexus_standalone_operation_failure
    with_nexus_client do |nexus_client, _endpoint|
      op_id = SecureRandom.uuid
      err = assert_raises(Temporalio::Error::NexusOperationFailedError) do
        nexus_client.execute_operation('echo', 'operation-error', id: op_id, schedule_to_close_timeout: 30)
      end
      assert_equal op_id, err.operation_id
      refute_nil err.cause
    end
  end

  private

  def with_nexus_client
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"
      yield env.client.create_nexus_client(endpoint, 'test-service'), endpoint
    end
  end
end
