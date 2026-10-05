# frozen_string_literal: true

require 'temporalio/activity'
require 'temporalio/testing/activity_environment'
require 'test'

module Testing
  class ActivityEnvironmentTest < Test
    also_run_all_tests_in_fiber

    class SimpleActivity < Temporalio::Activity::Definition
      def initialize(init_arg = 'init-arg')
        @init_arg = init_arg
      end

      def execute(exec_arg, raise = false) # rubocop:disable Style/OptionalBooleanParameter
        raise ArgumentError, 'Intentional error' if raise

        Temporalio::Activity::Context.current.heartbeat(123, '456')
        "init arg: #{@init_arg}, exec arg: #{exec_arg}, id: #{Temporalio::Activity::Context.current.info.activity_id}"
      end
    end

    def test_defaults
      env = Temporalio::Testing::ActivityEnvironment.new
      assert_equal 'init arg: init-arg, exec arg: arg1, id: test', env.run(SimpleActivity, 'arg1')
      assert_equal 'init arg: init-arg2, exec arg: arg2, id: test',
                   env.run(SimpleActivity.new('init-arg2'), 'arg2')
      assert_equal 'exec arg: arg3, id: test',
                   env.run(
                     Temporalio::Activity::Definition::Info.new(name: 'SimpleActivity') do |arg|
                       "exec arg: #{arg}, id: #{Temporalio::Activity::Context.current.info.activity_id}"
                     end,
                     'arg3'
                   )
      err = assert_raises(ArgumentError) { env.run(SimpleActivity, 'arg4', true) }
      assert_equal 'Intentional error', err.message
    end

    class WaitCancelActivity < Temporalio::Activity::Definition
      def execute
        Temporalio::Activity::Context.current.cancellation.wait
      end
    end

    def test_cancellation
      cancellation, cancel_proc = Temporalio::Cancellation.new
      env = Temporalio::Testing::ActivityEnvironment.new(cancellation:)
      err_queue = Queue.new
      run_in_background do
        env.run(WaitCancelActivity)
      rescue StandardError => e
        err_queue.push(e)
      end
      cancel_proc.call
      assert_instance_of Temporalio::Error::CanceledError, err_queue.pop
    end

    class WaitFiberCancelActivity < Temporalio::Activity::Definition
      activity_executor :fiber

      def execute
        Temporalio::Activity::Context.current.cancellation.wait
      end
    end

    def test_fiber_cancellation
      skip 'Must be fiber-based worker to do fiber-based activities' if Fiber.current_scheduler.nil?
      cancellation, cancel_proc = Temporalio::Cancellation.new
      env = Temporalio::Testing::ActivityEnvironment.new(cancellation:)
      err_queue = Queue.new
      run_in_background do
        env.run(WaitCancelActivity)
      rescue StandardError => e
        err_queue.push(e)
      end
      cancel_proc.call
      assert_instance_of Temporalio::Error::CanceledError, err_queue.pop
    end

    class HeartbeatingActivity < Temporalio::Activity::Definition
      def execute
        Temporalio::Activity::Context.current.heartbeat(123, '456')
        Temporalio::Activity::Context.current.heartbeat(Temporalio::Activity::Context.current.info.activity_id)
      end
    end

    def test_heartbeating
      queue = Queue.new
      info = Temporalio::Testing::ActivityEnvironment.default_info.with(activity_id: 'other-id')
      env = Temporalio::Testing::ActivityEnvironment.new(
        info:,
        on_heartbeat: proc { |args| queue.push(args) }
      )
      env.run(HeartbeatingActivity)
      assert_equal [123, '456'], queue.pop
      assert_equal ['other-id'], queue.pop
    end

    class CancellationDetailsActivity < Temporalio::Activity::Definition
      def initialize(started_queue)
        @started_queue = started_queue
      end

      def execute
        @started_queue << 'started'
        ctx = Temporalio::Activity::Context.current
        ctx.cancellation.wait
        ctx.cancellation.check!
        'not canceled'
      rescue Temporalio::Error::CanceledError
        det = Temporalio::Activity::Context.current.cancellation_details
        "canceled, requested: #{det&.cancel_requested?}, paused: #{det&.paused?}"
      end
    end

    def test_cancellation_details
      # Without detail callback set
      cancellation, cancel_proc = Temporalio::Cancellation.new
      env = Temporalio::Testing::ActivityEnvironment.new(cancellation:)
      started_queue = Queue.new
      res_queue = Queue.new
      run_in_background { res_queue << env.run(CancellationDetailsActivity.new(started_queue)) }
      started_queue.pop(timeout: 5)
      cancel_proc.call
      assert_equal 'canceled, requested: true, paused: false', res_queue.pop(timeout: 5)

      # With detail callback set
      cancellation, cancel_proc = Temporalio::Cancellation.new
      env = Temporalio::Testing::ActivityEnvironment.new(
        cancellation:,
        on_cancellation_details: proc do
          Temporalio::Activity::CancellationDetails.new(cancel_requested: false, paused: true)
        end
      )
      started_queue = Queue.new
      res_queue = Queue.new
      run_in_background { res_queue << env.run(CancellationDetailsActivity.new(started_queue)) }
      started_queue.pop(timeout: 5)
      cancel_proc.call
      assert_equal 'canceled, requested: false, paused: true', res_queue.pop(timeout: 5)
    end
  end
end
