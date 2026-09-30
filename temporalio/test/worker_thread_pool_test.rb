# frozen_string_literal: true

require 'temporalio/worker/thread_pool'
require 'test'
require 'thread_context_recorder'

class WorkerThreadPoolTest < Test
  # Raises the first `fail_times` invocations, then yields. `count` is the number of
  # invocations/threads.
  class CountingContext < Temporalio::Worker::ThreadPool::ThreadContext
    def initialize(fail_times:, restart_worker: false)
      super(restart_worker:)
      @fail_times = fail_times
      @mutex = Mutex.new
      @count = 0
    end

    def count
      @mutex.synchronize { @count }
    end

    def call
      n = @mutex.synchronize { @count += 1 }
      raise "context failed (attempt #{n})" if n <= @fail_times

      yield
    end
  end

  # Polls the block until it returns truthy or `timeout` elapses.
  def wait_until(timeout: 10)
    deadline = Time.now + timeout
    loop do
      result = yield
      return result if result || Time.now > deadline

      sleep(0.02)
    end
  end

  # Blocks until the pool runs something on a thread, so the thread is known to exist and to have
  # entered its context. Fails rather than hanging if that never happens.
  def run_and_wait(pool, timeout: 10)
    done = Queue.new
    pool.execute { done.push(:ran) }
    assert_equal :ran, done.pop(timeout:), 'pool never ran the block'
  end

  def test_default_context_is_no_op
    pool = Temporalio::Worker::ThreadPool.new
    ran = Queue.new
    pool.execute { ran.push(42) }
    seen = ran.pop(timeout: 10)
    assert_equal seen, 42, 'pool never ran the block'
  ensure
    pool&.shutdown
  end

  def test_context_wraps_work_on_the_thread
    context = ThreadContextRecorder.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    seen = Queue.new
    pool.execute { seen.push(Thread.current[ThreadContextRecorder::VALUE_KEY]) }

    assert_equal 'acquired', seen.pop(timeout: 10)
    refute_empty context.entered
    assert_empty context.exited, 'context must not have exited while the thread is still alive'
  ensure
    pool&.shutdown
  end

  def test_context_wraps_every_thread_in_the_pool
    context = ThreadContextRecorder.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    release = Queue.new
    seen = Queue.new
    # Ensure two threads are running.
    2.times do
      pool.execute do
        seen.push(Thread.current[ThreadContextRecorder::VALUE_KEY])
        release.pop
      end
    end
    assert_equal %w[acquired acquired], [seen.pop, seen.pop]
    2.times { release.push(nil) }

    assert_equal 2, pool.largest_length
    assert_equal 2, context.entered.size
  ensure
    2.times { release&.push(nil) }
    pool&.shutdown
  end

  def test_context_released_on_graceful_shutdown
    context = ThreadContextRecorder.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)
    run_and_wait(pool)
    assert_empty context.exited

    pool.shutdown

    assert wait_until { !context.exited.empty? }, 'context did not exit on graceful shutdown'
  end

  def test_context_released_on_idle_timeout_prune
    context = ThreadContextRecorder.new
    # We need two threads to make sure there is one that can be pruned.
    pool = Temporalio::Worker::ThreadPool.new(idle_timeout: 0.05, thread_context: context)
    release = Queue.new
    started = Queue.new
    2.times do
      pool.execute do
        started.push(:started)
        release.pop
      end
    end
    2.times { assert_equal :started, started.pop(timeout: 10), 'thread never started' }
    2.times { release.push(nil) }
    assert wait_until { pool.active_count.zero? }, 'threads did not go idle'
    assert_equal 2, pool.length
    assert_empty context.exited

    # Pruning only happens inside `execute`.
    sleep(0.2)
    pruned = wait_until do
      pool.execute { nil }
      !context.exited.empty?
    end
    assert pruned, 'context did not exit when its idle thread was pruned'
    assert wait_until { pool.length < 2 }, 'pruned thread was not removed from the pool'
  ensure
    pool&.shutdown
  end

  def test_context_released_on_kill
    context = ThreadContextRecorder.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)
    started = Queue.new
    blocked = Queue.new
    pool.execute do
      started.push(:started)
      blocked.pop # blocks
    end
    assert_equal :started, started.pop(timeout: 10), 'thread never started'
    assert_empty context.exited

    pool.kill

    assert wait_until { !context.exited.empty? }, 'context did not exit on kill'
  end

  def test_stop_runs_code_after_the_yield
    context = ThreadContextRecorder.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)
    run_and_wait(pool)
    assert_empty context.returned

    pool.shutdown

    assert wait_until { !context.exited.empty? }, 'context did not exit on graceful shutdown'
    refute_empty context.returned, 'stop did not return through the context; code after the yield never ran'
  end

  def test_kill_does_not_run_code_after_the_yield
    context = ThreadContextRecorder.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)
    started = Queue.new
    blocked = Queue.new
    pool.execute do
      started.push(:started)
      blocked.pop # blocks
    end
    assert_equal :started, started.pop(timeout: 10), 'thread never started'

    pool.kill

    assert wait_until { !context.exited.empty? }, 'context did not exit on kill'
    assert_empty context.returned, 'kill let the context return normally'
  end

  def test_raising_context_kills_only_its_own_thread
    context = CountingContext.new(fail_times: 1)
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    # Submit both up front. The first worker's context raises, so that worker never completes a
    # task and so never enters the ready list -- which makes the second `execute` create a fresh
    # worker rather than reuse the dead one.
    first = Queue.new
    second = Queue.new
    safe_capture_io do
      pool.execute { first.push(:ran) }
      pool.execute { second.push(:ran) }

      assert wait_until { context.count >= 1 }, 'context never raised'
      assert_equal :ran, second.pop(timeout: 10), 'second thread never ran its work'
    end

    assert_empty first, 'block ran even though its context raised'
    assert_equal 2, pool.largest_length
  ensure
    pool&.kill
  end

  # A worker whose context raises must not be left in the pool with a dead thread behind it.
  def test_raising_context_removes_its_worker_from_the_pool
    context = CountingContext.new(fail_times: Float::INFINITY)
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    safe_capture_io do
      pool.execute { nil }
      assert wait_until { context.count >= 1 }, 'context never raised'
    end

    assert wait_until { pool.length.zero? }, # rubocop:disable Style/ZeroLengthPredicate
           'dead worker was left in the pool'
  ensure
    pool&.kill
  end

  def test_raising_context_does_not_spawn_replacement_threads
    context = CountingContext.new(fail_times: Float::INFINITY)
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    safe_capture_io do
      pool.execute { nil }
      assert wait_until { context.count >= 1 }, 'context never raised'
    end

    sleep(0.5)
    assert_equal 1, context.count, 'context ran on new replacement threads'
  ensure
    pool&.kill
  end

  def test_kill_does_not_spawn_replacement_threads
    context = ThreadContextRecorder.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)
    run_and_wait(pool)
    assert_equal 1, pool.length

    pool.kill

    assert wait_until { !context.exited.empty? }, 'context did not exit on kill'
    sleep(0.3)
    assert_equal 0, pool.length, 'kill left workers in the pool'
    assert_equal 1, pool.largest_length, 'kill spawned a replacement thread'
  end

  def test_restart_worker_restarts_the_thread_until_the_context_succeeds
    context = CountingContext.new(fail_times: 10, restart_worker: true)
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    safe_capture_io do
      pool.execute { nil }
      # Each restart re-invokes the context with no further work submitted, so reaching 11 means
      # the 10 failures each produced a replacement thread.
      assert wait_until { context.count >= 11 }, "context ran #{context.count} times, wanted 11"
    end

    sleep(0.3)
    assert_equal 11, context.count, 'context kept restarting after it stopped raising'
    assert_equal 1, pool.length, 'only the last restart should leave a thread in the pool'

    live = pool.instance_variable_get(:@pool)
    ready = pool.instance_variable_get(:@ready).map(&:first)
    assert_empty ready.reject { |w| live.include?(w) }, 'restarts left dead workers in the ready list'

    ran = Queue.new
    10.times { pool.execute { ran.push(:ran) } }
    assert wait_until { ran.size == 10 }, "only #{ran.size} of 10 tasks ran after the restarts"
  ensure
    pool&.kill
  end

  def test_base_context_is_abstract
    assert_raises(NotImplementedError) { Temporalio::Worker::ThreadPool::ThreadContext.new.call { nil } }
  end
end
