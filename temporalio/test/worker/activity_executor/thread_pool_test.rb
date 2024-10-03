# frozen_string_literal: true

require 'temporalio/activity'
require 'test'

module Worker
  module ActivityExecutor
    class ThreadPoolTest < Test
      DO_NOTHING_ACTIVITY = Temporalio::Activity::Definition.new(name: 'ignore') do
        # Empty
      end

      def test_unlimited_max_with_idle
        pool = Temporalio::Worker::ActivityExecutor::ThreadPool.new(idle_timeout: 0.3)

        # Start some activities
        pending_activity_queues = Queue.new
        20.times do
          pool.execute_activity(DO_NOTHING_ACTIVITY) do
            queue = Queue.new
            pending_activity_queues << queue
            queue.pop
          end
        end

        # Wait for all to be waiting
        assert_eventually { assert_equal 20, pending_activity_queues.size }

        # Confirm some values
        assert_equal 20, pool.largest_length
        assert_equal 20, pool.scheduled_task_count
        assert_equal 0, pool.completed_task_count
        assert_equal 20, pool.active_count
        assert_equal 20, pool.length
        assert_equal 0, pool.queue_length

        # Complete 7 of the activities
        7.times { pending_activity_queues.pop << nil }

        # Confirm values have changed
        assert_eventually do
          assert_equal 20, pool.largest_length
          assert_equal 20, pool.scheduled_task_count
          assert_equal 7, pool.completed_task_count
          assert_equal 13, pool.active_count
          assert_equal 0, pool.queue_length
        end

        # Wait twice as long as the idle timeout and send an immediately
        # completing activity and confirm pool length trimmed down
        sleep(0.6)
        pool.execute_activity(DO_NOTHING_ACTIVITY) { nil }
        assert_eventually do
          assert pool.length == 13 || pool.length == 14, "Pool length: #{pool.length}"
        end

        # Finish the rest, shutdown, confirm eventually all done
        pending_activity_queues.pop << nil until pending_activity_queues.empty?
        pool.shutdown
        assert_eventually do
          assert_equal 20, pool.largest_length
          assert_equal 21, pool.scheduled_task_count
          assert_equal 21, pool.completed_task_count
          assert_equal 0, pool.length
        end
      end

      def test_limited_max
        pool = Temporalio::Worker::ActivityExecutor::ThreadPool.new(max_threads: 7)

        # Start some activities
        pending_activity_queues = Queue.new
        20.times do
          pool.execute_activity(DO_NOTHING_ACTIVITY) do
            queue = Queue.new
            pending_activity_queues << queue
            queue.pop
          end
        end

        # Wait for 7 to be waiting
        assert_eventually { assert_equal 7, pending_activity_queues.size }

        # Confirm some values
        assert_equal 7, pool.largest_length
        assert_equal 20, pool.scheduled_task_count
        assert_equal 0, pool.completed_task_count
        assert_equal 7, pool.active_count
        assert_equal 7, pool.length
        assert_equal 13, pool.queue_length

        # Complete 9 of the activities and confirm some values
        9.times { pending_activity_queues.pop << nil }
        assert_eventually do
          assert_equal 9, pool.completed_task_count
          assert_equal 7, pool.active_count
          assert_equal 7, pool.length
          # Only 4 left because 9 completed and 7 are running
          assert_equal 4, pool.queue_length
        end

        # Complete the rest
        11.times { pending_activity_queues.pop << nil }
        assert_eventually do
          assert_equal 20, pool.completed_task_count
          assert_equal 0, pool.queue_length
        end
      end
    end
  end
end
