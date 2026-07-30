# frozen_string_literal: true

require 'temporalio/internal/worker/workflow_instance/scheduler'
require 'test'

# The path is intentional: scheduler protobuf mutex detection keys off google/protobuf backtrace frames.
require_relative '../google/protobuf/scheduler_mutex_wait'

module Worker
  class WorkflowInstanceSchedulerTest < Test
    class FakeWorkflowInstance
      attr_reader :context

      def initialize
        @context = Object.new
      end

      define_method(:context_frozen) { false }

      def illegal_call_tracing_disabled
        yield
      end
    end

    def test_protobuf_mutex_wait_blocks_scheduler_drain_until_scheduler_unblocks_fiber
      scheduler = new_scheduler
      scheduler_thread = SchedulerThread.new(scheduler)
      mutex, release_mutex = held_mutex
      after_mutex = Queue.new

      scheduler_thread.call do
        scheduler.fiber do
          ProtobufSchedulerMutexWait.synchronize(mutex) { after_mutex << true }
        end
      end

      drain_result = scheduler_thread.async_call do
        scheduler.run_until_all_yielded
      end
      assert_thread_blocking_fiber_count(scheduler, 1)
      assert_empty after_mutex
      assert_empty drain_result

      blocked_fiber = thread_blocking_fibers(scheduler).first
      release_mutex.call
      scheduler.unblock(mutex, blocked_fiber)
      scheduler_thread.wait_result(drain_result)
      assert_equal true, after_mutex.pop(true)
      assert_thread_blocking_fiber_count(scheduler, 0)
    ensure
      release_mutex&.call
      unblock_thread_blocking_fibers(scheduler) if scheduler
      scheduler_thread&.stop
    end

    def test_regular_mutex_wait_remains_durable_scheduler_yield
      scheduler = new_scheduler
      scheduler_thread = SchedulerThread.new(scheduler)
      mutex, release_mutex = held_mutex
      after_mutex = Queue.new

      scheduler_thread.call do
        scheduler.fiber do
          mutex.synchronize { after_mutex << true }
        end
      end

      scheduler_thread.call do
        scheduler.run_until_all_yielded
      end
      assert_empty after_mutex
      assert_thread_blocking_fiber_count(scheduler, 0)

      release_mutex.call
      scheduler_thread.call do
        scheduler.run_until_all_yielded
      end
      assert_equal true, after_mutex.pop(true)
    ensure
      release_mutex&.call
      unblock_thread_blocking_fibers(scheduler) if scheduler
      scheduler_thread&.stop
    end

    def test_thread_blocking_fiber_settles_before_wait_condition_resolution
      scheduler = new_scheduler
      scheduler_thread = SchedulerThread.new(scheduler)
      mutex, release_mutex = held_mutex
      events = Queue.new

      scheduler_thread.call do
        scheduler.fiber do
          ProtobufSchedulerMutexWait.synchronize(mutex) { events << :protobuf_unblocked }
        end
        scheduler.fiber do
          scheduler.wait_condition(cancellation: nil) { true }
          events << :wait_condition_resumed
        end
      end

      drain_result = scheduler_thread.async_call do
        scheduler.run_until_all_yielded
      end
      assert_thread_blocking_fiber_count(scheduler, 1)
      assert_empty drain_queue(events)
      assert_empty drain_result

      blocked_fiber = thread_blocking_fibers(scheduler).first
      release_mutex.call
      scheduler.unblock(mutex, blocked_fiber)
      scheduler_thread.wait_result(drain_result)

      assert_equal %i[protobuf_unblocked wait_condition_resumed], drain_queue(events)
      assert_thread_blocking_fiber_count(scheduler, 0)
    ensure
      release_mutex&.call
      unblock_thread_blocking_fibers(scheduler) if scheduler
      scheduler_thread&.stop
    end

    class SchedulerThread
      def initialize(scheduler)
        @scheduler = scheduler
        @commands = Queue.new
        @thread = Thread.new do
          previous_scheduler = Fiber.scheduler
          Fiber.set_scheduler(scheduler)
          loop do
            command, result = @commands.pop
            break if command == :stop

            begin
              result << [:success, command.call]
            rescue Exception => e # rubocop:disable Lint/RescueException
              result << [:error, e]
            end
          end
        ensure
          Fiber.set_scheduler(previous_scheduler)
        end
      end

      def call(&)
        wait_result(async_call(&))
      end

      def async_call(&block)
        result = Queue.new
        @commands << [block, result]
        result
      end

      def wait_result(result)
        status, value = Timeout.timeout(2) { result.pop }
        raise value if status == :error

        value
      rescue Timeout::Error
        raise "Scheduler command did not finish: #{scheduler_state}\n#{@thread.backtrace&.join("\n")}"
      end

      def stop
        @commands << [:stop, Queue.new]
        raise 'Scheduler thread did not stop' unless @thread.join(2)

        @thread.value
      end

      def scheduler_state
        mutex = @scheduler.instance_variable_get(:@thread_blocking_mutex)
        mutex.synchronize do
          ready = @scheduler.instance_variable_get(:@ready).size
          blocking = @scheduler.instance_variable_get(:@thread_blocking_fibers).size
          "ready=#{ready} blocking=#{blocking}"
        end
      end
    end

    private

    def new_scheduler
      block = proc do
        Temporalio::Internal::Worker::WorkflowInstance::Scheduler.new(FakeWorkflowInstance.new) # steep:ignore
      end
      if defined?(SigApplicator)
        SigApplicator.suppress_errors { block.call }
      else
        block.call
      end
    end

    def held_mutex
      mutex = Mutex.new
      acquired = Queue.new
      release = Queue.new
      released = false
      holder = Thread.new do
        mutex.synchronize do
          acquired << true
          release.pop
        end
      end
      acquired.pop

      release_mutex = lambda do
        unless released
          released = true
          release << true
        end
        holder.join
      end
      [mutex, release_mutex]
    end

    def assert_thread_blocking_fiber_count(scheduler, expected_count)
      assert_eventually(timeout: 2.0, interval: 0.01) do
        assert_equal expected_count, thread_blocking_fiber_count(scheduler)
      end
    end

    def thread_blocking_fiber_count(scheduler)
      thread_blocking_fibers(scheduler).size
    end

    def thread_blocking_fibers(scheduler)
      mutex = scheduler.instance_variable_get(:@thread_blocking_mutex)
      mutex.synchronize do
        scheduler.instance_variable_get(:@thread_blocking_fibers).keys
      end
    end

    def unblock_thread_blocking_fibers(scheduler)
      thread_blocking_fibers(scheduler).each { |fiber| scheduler.unblock(nil, fiber) }
    end

    def drain_queue(queue)
      values = []
      values << queue.pop(true) until queue.empty?
      values
    end
  end
end
