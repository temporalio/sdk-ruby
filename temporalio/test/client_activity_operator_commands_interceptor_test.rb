# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

# Verifies each operator command (pause/unpause/reset/update_options) flows through the outbound
# client interceptor chain.
class ClientActivityOperatorCommandsInterceptorTest < Test
  class SlowActivity < Temporalio::Activity::Definition
    def execute
      Temporalio::Activity::Context.current.heartbeat
      sleep 0.1 until Temporalio::Activity::Context.current.cancellation.canceled?
      raise Temporalio::Error::CanceledError, 'canceled'
    end
  end

  class RecordingInterceptor
    include Temporalio::Client::Interceptor

    def initialize(events_array)
      @events = events_array
    end

    def intercept_client(next_interceptor)
      Outbound.new(next_interceptor, @events)
    end

    class Outbound < Temporalio::Client::Interceptor::Outbound
      def initialize(next_interceptor, events)
        super(next_interceptor)
        @events = events
      end

      def pause_activity(input)
        @events << 'pause_activity'
        super
      end

      def unpause_activity(input)
        @events << 'unpause_activity'
        super
      end

      def reset_activity(input)
        @events << 'reset_activity'
        super
      end

      def update_activity_options(input)
        @events << 'update_activity_options'
        super
      end
    end
  end

  def client_with_interceptor(events)
    interceptor = RecordingInterceptor.new(events)
    Temporalio::Client.new(**env.client.options.with(interceptors: [interceptor]).to_h)
  end

  def test_interceptor_invokes_each_operator_command
    events = []
    client = client_with_interceptor(events)
    task_queue = "saa-tq-#{SecureRandom.uuid}"
    worker = Temporalio::Worker.new(client: client, task_queue: task_queue, activities: [SlowActivity])
    worker.run do
      activity_id = "act-#{SecureRandom.uuid}"
      handle = client.start_activity(
        SlowActivity,
        id: activity_id, task_queue: task_queue, start_to_close_timeout: 60, heartbeat_timeout: 30
      )
      assert_eventually do
        assert_equal Temporalio::Client::PendingActivityState::STARTED, handle.describe.run_state
      end

      handle.pause('reason')
      # A running activity records PAUSE_REQUESTED first, only reaching PAUSED once the worker drops
      # the attempt; both count as paused for this flow-through assertion.
      paused_states = [
        Temporalio::Client::PendingActivityState::PAUSED,
        Temporalio::Client::PendingActivityState::PAUSE_REQUESTED
      ]
      assert_eventually do
        assert_includes paused_states, handle.describe.run_state
      end
      handle.unpause
      handle.update_options(start_to_close_timeout: 90.0)
      handle.reset

      handle.terminate('cleanup')
    end

    assert_includes events, 'pause_activity'
    assert_includes events, 'unpause_activity'
    assert_includes events, 'reset_activity'
    assert_includes events, 'update_activity_options'
  end
end
