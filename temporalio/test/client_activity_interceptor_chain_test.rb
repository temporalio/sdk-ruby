# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

class ClientActivityInterceptorChainTest < Test
  class SimpleActivity < Temporalio::Activity::Definition
    def execute
      'ok'
    end
  end

  # Records the order of calls through the interceptor chain.
  class RecordingInterceptor
    include Temporalio::Client::Interceptor

    attr_reader :events

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

      def start_activity(input)
        @events << "#{@name}:start_activity"
        super
      end

      def describe_activity(input)
        @events << "#{@name}:describe_activity"
        super
      end

      def cancel_activity(input)
        @events << "#{@name}:cancel_activity"
        super
      end

      def terminate_activity(input)
        @events << "#{@name}:terminate_activity"
        super
      end

      def list_activities(input)
        @events << "#{@name}:list_activities"
        super
      end

      def count_activities(input)
        @events << "#{@name}:count_activities"
        super
      end

      def fetch_activity_outcome(input)
        @events << "#{@name}:fetch_activity_outcome"
        super
      end
    end
  end

  def client_with_interceptors(interceptors)
    Temporalio::Client.new(**env.client.options.with(interceptors: interceptors).to_h)
  end

  def with_activity_worker(client, activities, &)
    task_queue = "saa-tq-#{SecureRandom.uuid}"
    worker = Temporalio::Worker.new(
      client: client,
      task_queue: task_queue,
      activities: activities
    )
    worker.run { yield task_queue }
  end

  def test_start_activity_interceptor_is_called
    events = []
    interceptor = RecordingInterceptor.new('A', events)
    client = client_with_interceptors([interceptor])
    with_activity_worker(client, [SimpleActivity]) do |task_queue|
      client.execute_activity(
        SimpleActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
    end
    # execute_activity is start_activity + result (which calls fetch_activity_outcome).
    assert_includes events, 'A:start_activity'
    assert_includes events, 'A:fetch_activity_outcome'
  end

  def test_describe_terminate_interceptors_called
    events = []
    interceptor = RecordingInterceptor.new('A', events)
    client = client_with_interceptors([interceptor])
    with_activity_worker(client, [SimpleActivity]) do |task_queue|
      handle = client.start_activity(
        SimpleActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      handle.describe
      handle.terminate('test')
    end
    assert_includes events, 'A:describe_activity'
    assert_includes events, 'A:terminate_activity'
  end

  def test_cancel_activity_interceptor_called
    events = []
    interceptor = RecordingInterceptor.new('A', events)
    client = client_with_interceptors([interceptor])
    with_activity_worker(client, [SimpleActivity]) do |task_queue|
      handle = client.start_activity(
        SimpleActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      # SimpleActivity is fast; the cancel RPC may race the activity's completion and the server
      # may reject it. The interceptor still runs client-side before the RPC, which is what we're
      # asserting. Swallow any RPC error.
      begin
        handle.cancel('test')
      rescue Temporalio::Error::RPCError
        # expected: cancel rejected after activity already completed
      end
    end
    assert_includes events, 'A:cancel_activity'
  end

  def test_list_and_count_activities_interceptors_called
    events = []
    interceptor = RecordingInterceptor.new('A', events)
    client = client_with_interceptors([interceptor])
    client.list_activities('').to_a
    client.count_activities('')
    assert_includes events, 'A:list_activities'
    assert_includes events, 'A:count_activities'
  end

  def test_two_interceptors_called_in_order_on_start
    events = []
    a = RecordingInterceptor.new('A', events)
    b = RecordingInterceptor.new('B', events)
    # First-added is outermost.
    client = client_with_interceptors([a, b])
    with_activity_worker(client, [SimpleActivity]) do |task_queue|
      client.execute_activity(
        SimpleActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
    end
    start_events = events.select { |e| e.end_with?(':start_activity') }
    assert_equal %w[A:start_activity B:start_activity], start_events
  end

  def test_interceptor_list_order_determines_call_order
    events = []
    b = RecordingInterceptor.new('B', events)
    a = RecordingInterceptor.new('A', events)
    # Order reversed from previous test.
    client = client_with_interceptors([b, a])
    with_activity_worker(client, [SimpleActivity]) do |task_queue|
      client.execute_activity(
        SimpleActivity,
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
    end
    # B is first-added, so it's outermost now.
    start_events = events.select { |e| e.end_with?(':start_activity') }
    assert_equal %w[B:start_activity A:start_activity], start_events
  end
end
