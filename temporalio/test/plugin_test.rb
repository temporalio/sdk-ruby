# frozen_string_literal: true

require 'securerandom'
require 'temporalio/simple_plugin'

class PluginTest < Test
  class ClientPluginForTest
    include Temporalio::Client::Plugin
    include Temporalio::Client::Interceptor

    attr_reader :name
    attr_accessor :start_workflow_called

    def initialize(target_host:, fail_connect: false)
      @name = 'some-plugin'
      @target_host = target_host
      @fail_connect = fail_connect
    end

    def configure_client(options)
      # Set interceptor
      options.with(interceptors: [self])
    end

    def connect_client(options, next_call)
      raise 'Intentional client failure' if @fail_connect

      # Set target host
      next_call.call(options.with(target_host: @target_host))
    end

    def intercept_client(next_interceptor)
      Interceptor.new(self, next_interceptor)
    end

    class Interceptor < Temporalio::Client::Interceptor::Outbound
      def initialize(plugin, next_interceptor)
        super(next_interceptor)
        @plugin = plugin
      end

      def start_workflow(input)
        @plugin.start_workflow_called = true
        super
      end
    end
  end

  class SimpleWorkflow < Temporalio::Workflow::Definition
    def execute(name)
      "Hello, #{name}!"
    end
  end

  def test_client_plugin
    # Connect with a plugin that fails on connect
    err = assert_raises do
      Temporalio::Client.connect(
        'bad',
        env.client.namespace,
        plugins: [ClientPluginForTest.new(target_host: env.client.connection.target_host, fail_connect: true)]
      )
    end
    assert_equal 'Intentional client failure', err.message

    # Connect with a plugin that sets address, run a workflow, confirm plugin properly configured interceptor
    plugin = ClientPluginForTest.new(target_host: env.client.connection.target_host)
    client = Temporalio::Client.connect('bad-address', env.client.namespace, plugins: [plugin])
    refute plugin.start_workflow_called
    client.start_workflow(SimpleWorkflow, 'some-name',
                          id: "wf-#{SecureRandom.uuid}", task_queue: "tq-#{SecureRandom.uuid}")
    assert plugin.start_workflow_called
  end

  class WorkerPluginForTest
    include Temporalio::Worker::Plugin
    include Temporalio::Worker::Interceptor::Workflow

    attr_reader :name
    attr_accessor :execute_workflow_called, :replay_workflow_called

    def initialize(fail_run: false)
      @name = 'some-plugin'
      @fail_run = fail_run
    end

    def configure_worker(options)
      options.with(workflows: [SimpleWorkflow], interceptors: [self])
    end

    def run_worker(options, next_call)
      raise 'Intentional worker failure' if @fail_run

      next_call.call(options)
    end

    def configure_workflow_replayer(options)
      options.with(workflows: [SimpleWorkflow], interceptors: [self])
    end

    def with_workflow_replay_worker(options, next_call)
      # Replace with our own replayer that will mark it called when called
      next_call.call(options.with(worker: OverrideReplayWorker.new(options.worker, self)))
    end

    def intercept_workflow(next_interceptor)
      Interceptor.new(self, next_interceptor)
    end

    class OverrideReplayWorker < SimpleDelegator
      def initialize(underlying, plugin)
        super(underlying)
        @plugin = plugin
      end

      def replay_workflow(*args, **kwargs)
        @plugin.replay_workflow_called = true
        super
      end
    end

    class Interceptor < Temporalio::Worker::Interceptor::Workflow::Inbound
      def initialize(plugin, next_interceptor)
        super(next_interceptor)
        @plugin = plugin
      end

      def execute(input)
        @plugin.execute_workflow_called = true
        super
      end
    end
  end

  def test_worker_plugin
    # Fail run
    err = assert_raises do
      Temporalio::Worker.new(client: env.client,
                             task_queue: "tq-#{SecureRandom.uuid}",
                             plugins: [WorkerPluginForTest.new(fail_run: true)])
                        .run { flunk }
    end
    assert_equal 'Intentional worker failure', err.message

    # Run workflow in worker, confirm interceptor hit
    plugin = WorkerPluginForTest.new
    worker = Temporalio::Worker.new(client: env.client, task_queue: "tq-#{SecureRandom.uuid}", plugins: [plugin])
    handle = worker.run do
      refute plugin.execute_workflow_called
      env.client.start_workflow(SimpleWorkflow, 'some-name',
                                id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue).tap do |handle|
        assert_equal 'Hello, some-name!', handle.result
        assert plugin.execute_workflow_called
      end
    end

    # Run replayer with a new version of the plugin
    plugin = WorkerPluginForTest.new
    replayer = Temporalio::Worker::WorkflowReplayer.new(workflows: [], plugins: [plugin])
    refute plugin.execute_workflow_called
    refute plugin.replay_workflow_called
    replayer.replay_workflow(handle.fetch_history)
    assert plugin.execute_workflow_called
    assert plugin.replay_workflow_called
  end

  class MethodsNotImplementedPlugin
    include Temporalio::Client::Plugin
    include Temporalio::Worker::Plugin
  end

  def test_plugin_methods_not_implemented
    err = assert_raises(ArgumentError) do
      Temporalio::Client.connect('does-not-matter', 'does-not-matter', plugins: [MethodsNotImplementedPlugin.new])
    end
    assert err.message.include?('missing') && err.message.include?('connect_client')
    err = assert_raises(ArgumentError) do
      Temporalio::Worker.new(client: env.client, task_queue: 'does-not-matter',
                             plugins: [MethodsNotImplementedPlugin.new])
    end
    assert err.message.include?('missing') && err.message.include?('run_worker')
  end

  class ToPayloadTrackingPayloadConverter < SimpleDelegator
    attr_accessor :to_payload_values

    def to_payload(value, **kwargs)
      (@to_payload_values ||= []) << value
      super
    end

    def to_payloads(values, **kwargs)
      (@to_payload_values ||= []).concat(values)
      super
    end
  end

  def test_simple_plugin
    # Create a simple plugin that just confirms some things are properly set
    payload_converter = ToPayloadTrackingPayloadConverter.new(Temporalio::Converters::PayloadConverter.default)
    run_context_calls = []
    plugin = Temporalio::SimplePlugin.new(
      name: 'simple-plugin',
      data_converter: Temporalio::Converters::DataConverter.new(payload_converter:),
      workflows: [SimpleWorkflow],
      run_context: proc do |options, next_call| # steep:ignore
        run_context_calls << options
        next_call.call(options) # steep:ignore
      end
    )

    # Create a client and worker with the plugin, run workflow, confirm success
    client = Temporalio::Client.connect(env.client.connection.target_host, env.client.namespace, plugins: [plugin])
    worker = Temporalio::Worker.new(client:, task_queue: "tq-#{SecureRandom.uuid}")
    handle = worker.run do
      client.start_workflow(SimpleWorkflow, 'some-name',
                            id: "wf-#{SecureRandom.uuid}",
                            task_queue: worker.task_queue).tap(&:result)
    end
    assert_equal 'Hello, some-name!', handle.result

    # Confirm custom payload converter called
    assert_equal ['some-name', 'Hello, some-name!'], payload_converter.to_payload_values

    # Run in replayer with same plugin
    replayer = Temporalio::Worker::WorkflowReplayer.new(workflows: [], plugins: [plugin])
    replayer.replay_workflow(handle.fetch_history)
    # Confirm payload converter called for this too
    assert_equal ['some-name', 'Hello, some-name!', 'Hello, some-name!'], payload_converter.to_payload_values
    # Confirm run context called for both
    assert_equal(
      [Temporalio::Worker::Plugin::RunWorkerOptions, Temporalio::Worker::Plugin::WithWorkflowReplayWorkerOptions],
      run_context_calls.map(&:class)
    )
  end
end
