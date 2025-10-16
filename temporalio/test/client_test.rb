# frozen_string_literal: true

require 'async'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

class ClientTest < Test
  def test_version_number
    assert !Temporalio::VERSION.nil?
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

  class TrackCallsInterceptor
    include Temporalio::Client::Interceptor

    attr_accessor :calls

    def initialize
      @calls = []
    end

    def intercept_client(next_interceptor)
      Outbound.new(self, next_interceptor)
    end

    class Outbound < Temporalio::Client::Interceptor::Outbound
      def initialize(root, next_interceptor)
        super(next_interceptor)
        @root = root
      end

      def start_workflow(input)
        @root.calls.push(['start_workflow', input])
        super
      end

      def list_workflow_page(input)
        @root.calls.push(['list_workflow_page', input])
        super
      end

      def count_workflows(input)
        @root.calls.push(['count_workflows', input])
        super
      end

      def describe_workflow(input)
        @root.calls.push(['describe_workflow', input])
        super
      end

      def fetch_workflow_history_events(input)
        @root.calls.push(['fetch_workflow_history_events', input])
        super
      end

      def signal_workflow(input)
        @root.calls.push(['signal_workflow', input])
        super
      end

      def query_workflow(input)
        @root.calls.push(['query_workflow', input])
        super
      end

      def start_workflow_update(input)
        @root.calls.push(['start_workflow_update', input])
        super
      end

      def poll_workflow_update(input)
        @root.calls.push(['poll_workflow_update', input])
        super
      end

      def cancel_workflow(input)
        @root.calls.push(['cancel_workflow', input])
        super
      end

      def terminate_workflow(input)
        @root.calls.push(['terminate_workflow', input])
        super
      end
    end
  end

  def test_interceptor
    # Create client with interceptor
    track = TrackCallsInterceptor.new
    new_options = env.client.options.with(interceptors: [track])
    client = Temporalio::Client.new(**new_options.to_h) # steep:ignore

    # Run a bunch of calls
    env.with_kitchen_sink_worker do |task_queue|
      handle = client.start_workflow(
        'kitchen_sink',
        {
          actions: [
            { query_handler: { name: 'some-query' } },
            { update_handler: { name: 'some-update' } }
          ],
          action_signal: 'some-signal'
        },
        id: "wf-#{SecureRandom.uuid}",
        task_queue:
      )
      # Query, update, signal, result, describe, cancel, terminate
      assert_equal 'query-done', handle.query('some-query', 'query-done')
      assert_equal 'update-done', handle.execute_update('some-update', 'update-done')
      handle.signal('some-signal', { result: { value: 'done' } })
      assert_equal 'done', handle.result
      assert_equal Temporalio::Client::WorkflowExecutionStatus::COMPLETED, handle.describe.status
      handle.cancel
      assert_raises(Temporalio::Error::RPCError) { handle.terminate }

      # Confirm those calls present
      assert_equal(%w[start_workflow query_workflow start_workflow_update signal_workflow
                      fetch_workflow_history_events describe_workflow cancel_workflow terminate_workflow],
                   track.calls.map(&:first))
      assert(track.calls.all? { |v| v.last.workflow_id == handle.id })

      # Clear it out and do non-id-specific calls
      track.calls.clear
      assert_empty client.list_workflows("WorkflowType = 'test-interceptor-does-not-exist'").to_a
      assert_equal 0, client.count_workflows("WorkflowType = 'test-interceptor-does-not-exist'").count
      assert_equal(%w[list_workflow_page count_workflows], track.calls.map(&:first))
    end
  end

  class SimpleWorkflow < Temporalio::Workflow::Definition
    def execute(name)
      "Hello, #{name}!"
    end
  end

  def test_fork
    # Cannot use client on other side of fork from where created
    pre_fork_client = env.client
    pid = fork do
      pre_fork_client.start_workflow(
        'some-workflow', id: "wf-#{SecureRandom.uuid}", task_queue: "tq-#{SecureRandom.uuid}"
      )
    rescue Temporalio::Internal::Bridge::Error => e
      exit! 123 if e.message.start_with?('Cannot use client across forks')
      raise
    end
    _, status = Process.wait2(pid)
    assert_equal 123, status.exitstatus

    # Cannot create client on other side of fork from runtime
    pid = fork do
      Temporalio::Client.connect(env.client.options.connection.target_host, env.client.options.namespace)
    rescue Temporalio::Internal::Bridge::Error => e
      exit! 234 if e.message.start_with?('Cannot create client across forks')
      raise
    end
    _, status = Process.wait2(pid)
    assert_equal 234, status.exitstatus

    # Cannot create worker on other side of fork from runtime. For whatever reason, the exit status is overwritten here
    # so we use a pipe to relay back
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      Temporalio::Worker.new(
        client: pre_fork_client, task_queue: "tq-#{SecureRandom.uuid}", workflows: [SimpleWorkflow]
      )
      writer.puts 'success'
    rescue Temporalio::Internal::Bridge::Error => e
      writer.puts e.message.start_with?('Cannot create worker across forks') ? 'fork-fail' : 'fail'
      exit!
    end
    Process.wait2(pid)
    writer.close
    assert_equal 'fork-fail', reader.read.strip

    # Cannot use worker on other side of fork from runtime. For whatever reason, the exit status is overwritten here
    # so we use a pipe to relay back
    pre_fork_worker = Temporalio::Worker.new(
      client: pre_fork_client, task_queue: "tq-#{SecureRandom.uuid}", workflows: [SimpleWorkflow]
    )
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      pre_fork_worker.run
      writer.puts 'success'
    rescue Temporalio::Internal::Bridge::Error => e
      writer.puts e.message.start_with?('Cannot use worker across forks') ? 'fork-fail' : 'fail'
      exit!
    end
    Process.wait2(pid)
    writer.close
    assert_equal 'fork-fail', reader.read.strip

    # But use of a client in the fork with its own runtime is fine
    reader, writer = IO.pipe
    pid = fork do
      reader.close
      client = Temporalio::Client.connect(
        env.client.options.connection.target_host,
        env.client.options.namespace,
        runtime: Temporalio::Runtime.new,
        logger: Logger.new($stdout)
      )
      handle = client.start_workflow(
        SimpleWorkflow, 'some-user',
        id: "wf-#{SecureRandom.uuid}", task_queue: "tq-#{SecureRandom.uuid}"
      )
      writer.puts('started workflow')
      handle.terminate
      exit! 0
    end
    _, status = Process.wait2(pid)
    writer.close
    assert status.success?
    assert_equal 'started workflow', reader.read.strip
  end

  def test_binary_metadata
    orig_metadata = env.client.connection.rpc_metadata

    # Connect a new client with some bad metadata
    err = assert_raises(ArgumentError) do
      Temporalio::Client.connect(
        env.client.connection.target_host,
        env.client.namespace,
        rpc_metadata: { 'connect-bin' => 'not-allowed' }
      )
    end
    assert_equal 'Value for metadata key connect-bin must be ASCII-8BIT', err.message

    # Update a client with some bad metadata
    err = assert_raises(ArgumentError) do
      env.client.connection.rpc_metadata = { 'update-bin' => 'not-allowed' }
    end
    assert_equal 'Value for metadata key update-bin must be ASCII-8BIT', err.message

    # Make an RPC call with some bad metadata
    err = assert_raises(ArgumentError) do
      env.client.start_workflow(
        :MyWorkflow,
        id: "wf-#{SecureRandom.uuid}",
        task_queue: "tq-#{SecureRandom.uuid}",
        rpc_options: Temporalio::Client::RPCOptions.new(metadata: { 'rpc-bin' => 'not-allowed' })
      )
    end
    assert_equal 'Value for metadata key rpc-bin must be ASCII-8BIT', err.message
  ensure
    env.client.connection.rpc_metadata = orig_metadata
  end

  class ScheduleResult
    def initialize(client, handle)
      @handle = handle
      @client = client
    end

    def result
      desc = @handle.describe
      # oldest first
      workflow_id = desc.info.recent_actions.last&.action&.workflow_id
      return nil if workflow_id.nil?

      workflow_handle = @client.workflow_handle(workflow_id)
      workflow_handle.result
    end
  end

  class LastResultWorkflow < Temporalio::Workflow::Definition
    def execute
      last_result = Temporalio::Workflow.info.last_result
      return "The last result was #{last_result}" unless last_result.nil?

      'First result'
    end
  end

  def test_last_completion_result
    id = "wf-#{SecureRandom.uuid}"
    task_queue = "tq-#{SecureRandom.uuid}"
    handle = env.client.create_schedule(
      'last-result-workflow',
      Temporalio::Client::Schedule.new(
        action: Temporalio::Client::Schedule::Action::StartWorkflow.new(
          LastResultWorkflow,
          id:, task_queue:
        ),
        spec: Temporalio::Client::Schedule::Spec.new
      )
    )

    schedule = ScheduleResult.new(env.client, handle)

    Temporalio::Worker.new(client: env.client, task_queue:, workflows: [LastResultWorkflow]).run do
      handle.trigger
      assert_equal 'First result', schedule.result

      handle.trigger
      assert_equal 'The last result was First result', schedule.result
    end

    handle.delete
  end

  class HasLastResultWorkflow < Temporalio::Workflow::Definition
    def execute # rubocop:disable Naming/PredicateMethod
      Temporalio::Workflow.info.has_last_result?
    end
  end

  def test_has_last_completion_result
    id = "wf-#{SecureRandom.uuid}"
    task_queue = "tq-#{SecureRandom.uuid}"
    handle = env.client.create_schedule(
      'has-last-result-workflow',
      Temporalio::Client::Schedule.new(
        action: Temporalio::Client::Schedule::Action::StartWorkflow.new(
          HasLastResultWorkflow,
          id:, task_queue:
        ),
        spec: Temporalio::Client::Schedule::Spec.new
      )
    )

    schedule = ScheduleResult.new(env.client, handle)

    Temporalio::Worker.new(client: env.client, task_queue:, workflows: [HasLastResultWorkflow]).run do
      handle.trigger
      assert_equal false, schedule.result

      handle.trigger
      assert_equal true, schedule.result
    end

    handle.delete
  end
end
