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

    attr_reader :inputs

    def initialize(events_array)
      @events = events_array
      @inputs = {}
    end

    def intercept_client(next_interceptor)
      Outbound.new(next_interceptor, @events, @inputs)
    end

    class Outbound < Temporalio::Client::Interceptor::Outbound
      def initialize(next_interceptor, events, inputs)
        super(next_interceptor)
        @events = events
        @inputs = inputs
      end

      def pause_activity(input)
        @events << 'pause_activity'
        @inputs[:pause_activity] = input
        super
      end

      def unpause_activity(input)
        @events << 'unpause_activity'
        @inputs[:unpause_activity] = input
        super
      end

      def reset_activity(input)
        @events << 'reset_activity'
        @inputs[:reset_activity] = input
        super
      end

      def update_activity_options(input)
        @events << 'update_activity_options'
        @inputs[:update_activity_options] = input
        super
      end
    end
  end

  def client_with_interceptor(events, recorder: nil)
    interceptor = recorder || RecordingInterceptor.new(events)
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
      paused_states = [
        Temporalio::Client::PendingActivityState::PAUSED,
        Temporalio::Client::PendingActivityState::PAUSE_REQUESTED
      ]
      assert_eventually do
        assert_includes paused_states, handle.describe.run_state
      end
      handle.unpause
      handle.update_options(Temporalio::Client::ActivityOptions::START_TO_CLOSE_TIMEOUT.value_set(90.0))
      handle.reset

      handle.terminate('cleanup')
    end

    assert_includes events, 'pause_activity'
    assert_includes events, 'unpause_activity'
    assert_includes events, 'reset_activity'
    assert_includes events, 'update_activity_options'
  end

  # Asserts the values a caller passes reach the interceptor chain, not merely that the hook
  # fired. A dropped argument between the handle and the chain is invisible to a test that only
  # checks which events were recorded.
  def test_interceptor_receives_command_arguments
    events = []
    recorder = RecordingInterceptor.new(events)
    client = client_with_interceptor(events, recorder:)
    task_queue = "saa-tq-#{SecureRandom.uuid}"
    worker = Temporalio::Worker.new(client:, task_queue:, activities: [SlowActivity])
    worker.run do
      handle = client.start_activity(
        SlowActivity,
        id: "act-#{SecureRandom.uuid}", task_queue:, start_to_close_timeout: 60, heartbeat_timeout: 30
      )
      assert_eventually do
        assert_equal Temporalio::Client::PendingActivityState::STARTED, handle.describe.run_state
      end

      handle.pause('pause-reason')
      handle.unpause(reason: 'unpause-reason', jitter: 5.0)
      handle.reset(keep_paused: true, reset_heartbeat: true)
      handle.terminate('cleanup')
    end

    assert_equal 'pause-reason', recorder.inputs[:pause_activity].reason
    assert_equal 'unpause-reason', recorder.inputs[:unpause_activity].reason
    assert_equal 5.0, recorder.inputs[:unpause_activity].jitter
    assert recorder.inputs[:reset_activity].keep_paused
    assert recorder.inputs[:reset_activity].reset_heartbeat
    refute recorder.inputs[:reset_activity].restore_original_options
  end
end
