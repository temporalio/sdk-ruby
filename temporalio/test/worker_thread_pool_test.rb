# frozen_string_literal: true

require 'temporalio/worker/thread_pool'
require 'test'

class WorkerThreadPoolTest < Test
  class RecordingContext < Temporalio::Worker::ThreadPool::ThreadContext
    attr_reader :entered, :exited

    def initialize(var_value: 'set-by-context')
      super()
      @var_value = var_value
      @entered = Queue.new
      @exited = Queue.new
    end

    def call
      Thread.current[:test_thread_context_var] = @var_value
      @entered.push(Thread.current.name)
      yield
    ensure
      Thread.current[:test_thread_context_var] = nil
      @exited.push(Thread.current.name)
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
    context = RecordingContext.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    seen = Queue.new
    pool.execute { seen.push(Thread.current[:test_thread_context_var]) }

    assert_equal 'set-by-context', seen.pop(timeout: 10)
    refute_empty context.entered
    assert_empty context.exited, 'context must not have exited while the thread is still alive'
  ensure
    pool&.shutdown
  end

  def test_context_wraps_every_thread_in_the_pool
    context = RecordingContext.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    release = Queue.new
    seen = Queue.new
    # Ensure two threads are running.
    2.times do
      pool.execute do
        seen.push(Thread.current[:test_thread_context_var])
        release.pop
      end
    end
    assert_equal %w[set-by-context set-by-context], [seen.pop, seen.pop]
    2.times { release.push(nil) }

    assert_equal 2, pool.largest_length
    assert_equal 2, context.entered.size
  ensure
    2.times { release&.push(nil) }
    pool&.shutdown
  end

  def test_context_released_on_graceful_shutdown
    context = RecordingContext.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)
    run_and_wait(pool)
    assert_empty context.exited

    pool.shutdown

    assert wait_until { !context.exited.empty? }, 'context did not exit on graceful shutdown'
  end

  def test_context_released_on_idle_timeout_prune
    context = RecordingContext.new
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
    context = RecordingContext.new
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

  # Raises for the first thread only, so the second thread's context succeeds.
  class RaisesOnceContext < Temporalio::Worker::ThreadPool::ThreadContext
    attr_reader :raised

    def initialize
      super
      @mutex = Mutex.new
      @raised = Queue.new
      @first = true
    end

    def call
      should_raise = @mutex.synchronize { @first ? (@first = false) || true : false }
      if should_raise
        @raised.push(:raised)
        raise 'context failed'
      end

      yield
    end
  end

  def test_raising_context_kills_only_its_own_thread
    context = RaisesOnceContext.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    # Submit both up front. The first worker's context raises, so that worker never completes a
    # task and so never enters the ready list -- which makes the second `execute` create a fresh
    # worker rather than reuse the dead one.
    first = Queue.new
    second = Queue.new
    # Captured only to keep the dying thread's report_on_exception warning out of the test output.
    capture_subprocess_io do
      pool.execute { first.push(:ran) }
      pool.execute { second.push(:ran) }

      assert_equal :raised, context.raised.pop(timeout: 10), 'context never raised'
      assert_equal :ran, second.pop(timeout: 10), 'second thread never ran its work'
    end

    # Its worker is dead, so nothing can ever pop this block; no waiting needed to establish that.
    assert_empty first, 'block ran even though its context raised'
    assert_equal 2, pool.largest_length
  ensure
    pool&.kill
  end

  class AlwaysRaisesContext < Temporalio::Worker::ThreadPool::ThreadContext
    attr_reader :raised

    def initialize
      super
      @raised = Queue.new
    end

    def call
      @raised.push(:raised)
      raise 'context failed'
    end
  end

  # A worker whose context raises must not be left in the pool with a dead thread behind it.
  def test_raising_context_removes_its_worker_from_the_pool
    context = AlwaysRaisesContext.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    capture_subprocess_io do
      pool.execute { nil }
      assert_equal :raised, context.raised.pop(timeout: 10), 'context never raised'
    end

    # ThreadPool exposes `length` but no `empty?`.
    assert wait_until { pool.length.zero? }, # rubocop:disable Style/ZeroLengthPredicate
           'dead worker was left in the pool'
  ensure
    pool&.kill
  end

  # The cleanup must not ask for a replacement: a context that fails once generally fails every
  # time, so replacing on failure spawns threads without bound.
  def test_raising_context_does_not_spawn_replacement_threads
    context = AlwaysRaisesContext.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    capture_subprocess_io do
      pool.execute { nil }
      # Left on the queue rather than popped, so its size counts context invocations.
      assert wait_until { !context.raised.empty? }, 'context never raised'
      sleep(0.5)
    end

    # One submission, one thread, so the context ran exactly once. Replacing the worker on failure
    # produced tens of thousands of invocations here.
    assert_equal 1, context.raised.size, 'context ran on replacement threads'
  ensure
    pool&.kill
  end

  # `ThreadPool#kill` already drops every worker, so the cleanup must not resurrect any.
  def test_kill_does_not_resurrect_workers
    context = RecordingContext.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)
    run_and_wait(pool)
    assert_equal 1, pool.length

    pool.kill

    assert wait_until { !context.exited.empty? }, 'context did not exit on kill'
    sleep(0.3)
    assert_equal 0, pool.length, 'kill left workers in the pool'
    assert_equal 1, pool.largest_length, 'kill spawned a replacement thread'
  end

  # Raises the first `fail_times` invocations, then yields. Each invocation is a fresh thread when
  # restart_worker is on, so the count doubles as a count of threads started.
  class RestartingContext < Temporalio::Worker::ThreadPool::ThreadContext
    def initialize(fail_times:)
      super(restart_worker: true)
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

  def test_restart_worker_restarts_the_thread_until_the_context_succeeds
    context = RestartingContext.new(fail_times: 10)
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    capture_subprocess_io do
      pool.execute { nil }
      # Each restart re-invokes the context with no further work submitted, so reaching 11 means
      # the 10 failures each produced a replacement thread.
      assert wait_until { context.count >= 11 }, "context ran #{context.count} times, wanted 11"
    end

    # The 11th invocation yielded, so that thread stays alive and restarting stops.
    sleep(0.3)
    assert_equal 11, context.count, 'context kept restarting after it stopped raising'
    assert_equal 1, pool.length, 'the surviving thread is not in the pool'
  ensure
    pool&.kill
  end

  def test_base_context_is_abstract
    assert_raises(NotImplementedError) { Temporalio::Worker::ThreadPool::ThreadContext.new.call { nil } }
  end
end
