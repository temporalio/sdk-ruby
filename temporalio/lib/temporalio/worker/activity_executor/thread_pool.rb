# frozen_string_literal: true

# Much of this logic taken from
# https://github.com/ruby-concurrency/concurrent-ruby/blob/044020f44b36930b863b930f3ee8fa1e9f750469/lib/concurrent-ruby/concurrent/executor/ruby_thread_pool_executor.rb,
# see MIT license at
# https://github.com/ruby-concurrency/concurrent-ruby/blob/044020f44b36930b863b930f3ee8fa1e9f750469/LICENSE.txt

module Temporalio
  class Worker
    class ActivityExecutor
      # Activity executor for scheduling activities in their own thread. This implementation is a stripped down form of
      # Concurrent Ruby's `CachedThreadPool`.
      class ThreadPool < ActivityExecutor
        # @return [ThreadPool] Default/shared thread pool executor instance with unlimited max threads.
        def self.default
          @default ||= new
        end

        # @!visibility private
        def self._monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        # Create a new thread pool executor that creates threads as needed.
        #
        # @param max_threads [Integer, nil] Maximum number of thread workers to create, or nil for unlimited max.
        # @param idle_timeout [Float] Number of seconds before a thread worker with no work should be stopped. Note,
        #   the check of whether a thread worker is idle is only done on each new activity.
        def initialize(max_threads: nil, idle_timeout: 20) # rubocop:disable Lint/MissingSuper
          @max_threads = max_threads
          @idle_timeout = idle_timeout

          @mutex = Mutex.new
          @pool = []
          @ready = []
          @queue = []
          @scheduled_task_count = 0
          @completed_task_count = 0
          @largest_length       = 0
          @workers_counter = 0
          @prune_interval = @idle_timeout / 2
          @next_prune_time = ThreadPool._monotonic_time + @prune_interval
        end

        # @see ActivityExecutor.execute_activity
        def execute_activity(_defn, &block)
          @mutex.synchronize do
            locked_assign_worker(&block) || locked_enqueue(&block)
            @scheduled_task_count += 1
            locked_prune_pool if @next_prune_time < ThreadPool._monotonic_time
          end
        end

        # @see ActivityExecutor.activity_context
        def activity_context
          Thread.current[:temporal_activity_context]
        end

        # @see ActivityExecutor.activity_context=
        def activity_context=(context)
          Thread.current[:temporal_activity_context] = context
          # If they have opted in to raising on cancel, wire that up
          return unless context&.definition&.cancel_raise

          thread = Thread.current
          context.cancellation.add_cancel_callback do
            thread.raise(Error::CanceledError.new('Activity canceled')) if thread[:temporal_activity_context] == context
          end
        end

        # @return [Integer] The largest number of threads that have been created in the pool since construction.
        def largest_length
          @mutex.synchronize { @largest_length }
        end

        # @return [Integer] The number of tasks that have been scheduled for execution on the pool since construction.
        def scheduled_task_count
          @mutex.synchronize { @scheduled_task_count }
        end

        # @return [Integer] The number of tasks that have been completed by the pool since construction.
        def completed_task_count
          @mutex.synchronize { @completed_task_count }
        end

        # @return [Integer] The number of threads that are actively executing tasks.
        def active_count
          @mutex.synchronize { @pool.length - @ready.length }
        end

        # @return [Integer] The number of threads currently in the pool.
        def length
          @mutex.synchronize { @pool.length }
        end

        # @return [Integer] The number of tasks in the queue awaiting execution.
        def queue_length
          @mutex.synchronize { @queue.length }
        end

        # Gracefully shutdown each thread when it is done with its current task. This should not be called until all
        # workers using this executor are complete. This does not need to be called at all on program exit (e.g. for the
        # global default).
        def shutdown
          @mutex.synchronize do
            # Stop all workers
            @pool.each(&:stop)
          end
        end

        # Kill each thread. This should not be called until all workers using this executor are complete. This does not
        # need to be called at all on program exit (e.g. for the global default).
        def kill
          @mutex.synchronize do
            # Kill all workers
            @pool.each(&:kill)
            @pool.clear
            @ready.clear
          end
        end

        # @!visibility private
        def _remove_busy_worker(worker)
          @mutex.synchronize { locked_remove_busy_worker(worker) }
        end

        # @!visibility private
        def _ready_worker(worker, last_message)
          @mutex.synchronize { locked_ready_worker(worker, last_message) }
        end

        # @!visibility private
        def _worker_died(worker)
          @mutex.synchronize { locked_worker_died(worker) }
        end

        # @!visibility private
        def _worker_task_completed
          @mutex.synchronize { @completed_task_count += 1 }
        end

        private

        def locked_assign_worker(&block)
          # keep growing if the pool is not at the minimum yet
          worker, = @ready.pop || locked_add_busy_worker
          if worker
            worker << block
            true
          else
            false
          end
        end

        def locked_enqueue(&block)
          @queue << block
        end

        def locked_add_busy_worker
          return if @max_threads && @pool.size >= @max_threads

          @workers_counter += 1
          @pool << (worker = Worker.new(self, @workers_counter))
          @largest_length = @pool.length if @pool.length > @largest_length
          worker
        end

        def locked_prune_pool
          now = ThreadPool._monotonic_time
          stopped_workers = 0
          while !@ready.empty? && (@pool.size - stopped_workers).positive?
            worker, last_message = @ready.first
            break unless now - last_message > @idle_timeout

            stopped_workers += 1
            @ready.shift
            worker << :stop

          end

          @next_prune_time = ThreadPool._monotonic_time + @prune_interval
        end

        def locked_remove_busy_worker(worker)
          @pool.delete(worker)
        end

        def locked_ready_worker(worker, last_message)
          block = @queue.shift
          if block
            worker << block
          else
            @ready.push([worker, last_message])
          end
        end

        def locked_worker_died(worker)
          locked_remove_busy_worker(worker)
          replacement_worker = locked_add_busy_worker
          locked_ready_worker(replacement_worker, ThreadPool._monotonic_time) if replacement_worker
        end

        # @!visibility private
        class Worker
          def initialize(pool, id)
            @queue = Queue.new
            @thread = Thread.new(@queue, pool) do |my_queue, my_pool|
              catch(:stop) do
                loop do
                  case block = my_queue.pop
                  when :stop
                    pool._remove_busy_worker(self)
                    throw :stop
                  else
                    begin
                      block.call
                      my_pool._worker_task_completed
                      my_pool._ready_worker(self, ThreadPool._monotonic_time)
                    rescue StandardError => e
                      # Ignore
                      warn("Unexpected activity block error: #{e}")
                    rescue Exception => e # rubocop:disable Lint/RescueException
                      warn("Unexpected activity block exception: #{e}")
                      my_pool._worker_died(self)
                      throw :stop
                    end
                  end
                end
              end
            end
            @thread.name = "activity-thread-#{id}"
          end

          # @!visibility private
          def <<(block)
            @queue << block
          end

          # @!visibility private
          def stop
            @queue << :stop
          end

          # @!visibility private
          def kill
            @thread.kill
          end
        end

        private_constant :Worker
      end
    end
  end
end
