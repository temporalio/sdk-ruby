# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

# Multi-interceptor ordering tests for the workflow client-call chain. Mirrors
# `test/client_activity_interceptor_chain_test.rb` so the convention documented in client.rb's YARD
# (`"The earlier interceptors wrap the later ones"`) is enforced for workflows the same way it is for
# the new SAA paths. Without these tests, a change to the chain assembly in client.rb (`reverse_each.reduce`)
# could swap the order silently.
class ClientWorkflowInterceptorChainTest < Test
  class SimpleWorkflow < Temporalio::Workflow::Definition
    def execute
      'ok'
    end
  end

  class RecordingInterceptor
    include Temporalio::Client::Interceptor

    def initialize(name, events_array)
      @name = name
      @events = events_array
    end

    def intercept_client(next_interceptor)
      Outbound.new(next_interceptor, @name, @events)
    end

    class Outbound < Temporalio::Client::Interceptor::Outbound
      def initialize(next_interceptor, name, events)
        super(next_interceptor)
        @name = name
        @events = events
      end

      def start_workflow(input)
        @events << "#{@name}:start_workflow"
        super
      end

      def describe_workflow(input)
        @events << "#{@name}:describe_workflow"
        super
      end

      def cancel_workflow(input)
        @events << "#{@name}:cancel_workflow"
        super
      end

      def terminate_workflow(input)
        @events << "#{@name}:terminate_workflow"
        super
      end

      def list_workflow_page(input)
        @events << "#{@name}:list_workflow_page"
        super
      end

      def count_workflows(input)
        @events << "#{@name}:count_workflows"
        super
      end

      def fetch_workflow_history_events(input)
        @events << "#{@name}:fetch_workflow_history_events"
        super
      end
    end
  end

  def client_with_interceptors(interceptors)
    Temporalio::Client.new(**env.client.options.with(interceptors: interceptors).to_h)
  end

  def with_workflow_worker(client, &block)
    task_queue = "wf-tq-#{SecureRandom.uuid}"
    worker = Temporalio::Worker.new(
      client: client,
      task_queue: task_queue,
      workflows: [SimpleWorkflow]
    )
    worker.run { yield task_queue }
  end

  def test_two_workflow_interceptors_called_in_order_on_start
    events = []
    a = RecordingInterceptor.new('A', events)
    b = RecordingInterceptor.new('B', events)
    # First-added is outermost, per the YARD doc on client.rb's interceptors param.
    client = client_with_interceptors([a, b])
    with_workflow_worker(client) do |task_queue|
      client.execute_workflow(
        SimpleWorkflow,
        id: "wf-#{SecureRandom.uuid}",
        task_queue: task_queue
      )
    end
    start_events = events.select { |e| e.end_with?(':start_workflow') }
    assert_equal %w[A:start_workflow B:start_workflow], start_events
  end

  def test_workflow_interceptor_list_order_determines_call_order
    events = []
    b = RecordingInterceptor.new('B', events)
    a = RecordingInterceptor.new('A', events)
    # Reverse order. B is now first-added, so B is outermost.
    client = client_with_interceptors([b, a])
    with_workflow_worker(client) do |task_queue|
      client.execute_workflow(
        SimpleWorkflow,
        id: "wf-#{SecureRandom.uuid}",
        task_queue: task_queue
      )
    end
    start_events = events.select { |e| e.end_with?(':start_workflow') }
    assert_equal %w[B:start_workflow A:start_workflow], start_events
  end
end
