# frozen_string_literal: true

require 'async'
require 'temporalio/client'
require 'temporalio/testing'
require 'test_base'

class ClientTest < TestBase
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

      def list_workflows(input)
        @root.calls.push(['list_workflows', input])
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
    new_options = env.client.options.dup
    new_options.interceptors = [track]
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
      assert_equal(%w[list_workflows count_workflows], track.calls.map(&:first))
    end
  end
end
