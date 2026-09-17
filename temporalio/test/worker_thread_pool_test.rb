# frozen_string_literal: true

require 'temporalio/worker/thread_pool'
require 'test'

class WorkerThreadPoolTest < Test
  # Records what happened on each thread it wraps. `entered`/`exited` are pushed to from pool
  # threads, so they are queues rather than plain arrays.
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

  # Polls the block until it returns truthy or `timeout` elapses, and returns the last result so
  # callers can assert on it. The block is evaluated once per iteration, so a block with side
  # effects runs a predictable number of times.
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
    # Wrapped, because the value under test is itself nil and a timed-out pop also returns nil.
    pool.execute { ran.push({ value: Thread.current[:test_thread_context_var] }) }
    seen = ran.pop(timeout: 10)
    refute_nil seen, 'pool never ran the block'
    assert_nil seen[:value]
  ensure
    pool&.shutdown
  end

  def test_context_wraps_work_on_the_thread
    context = RecordingContext.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)

    # The block the pool runs is the stand-in for an activity: it observes the variable the
    # context set in its preamble.
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

    # Occupy two threads at once so the pool has to start a second one.
    release = Queue.new
    seen = Queue.new
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

  # The doc's claim, for graceful shutdown. `shutdown` queues `:stop` for each worker; the worker
  # thread itself then runs `throw :stop`, which unwinds out through the context's `ensure`.
  def test_context_released_on_graceful_shutdown
    context = RecordingContext.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)
    run_and_wait(pool)
    assert_empty context.exited

    pool.shutdown

    assert wait_until { !context.exited.empty? }, 'context did not exit on graceful shutdown'
  end

  # Same claim, for the idle-timeout prune path, which also stops a thread with `throw :stop`.
  def test_context_released_on_idle_timeout_prune
    context = RecordingContext.new
    # Prune checks run on `execute`, and only stop threads that have been idle longer than the
    # timeout. Two threads are needed: `execute` hands the new task to one idle thread before
    # pruning, so a second must remain in the ready list for there to be anything to prune.
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

    # Let both threads age past the idle timeout, then drive a prune with one more task. Pruning
    # only happens inside `execute`, so the poll has to keep feeding it work.
    sleep(0.2)
    pruned = wait_until do
      pool.execute { nil }
      !context.exited.empty?
    end
    assert pruned, 'context did not exit when its idle thread was pruned'
    # The pruned thread is removed from the pool, not just told to stop.
    assert wait_until { pool.length < 2 }, 'pruned thread was not removed from the pool'
  ensure
    pool&.shutdown
  end

  # The doc predicted `ThreadPool#kill` would NOT release the resource. It does: `Thread#kill`
  # unwinds the stack and runs `ensure` blocks.
  def test_context_released_on_kill
    context = RecordingContext.new
    pool = Temporalio::Worker::ThreadPool.new(thread_context: context)
    started = Queue.new
    blocked = Queue.new
    pool.execute do
      started.push(:started)
      blocked.pop # never pushed to; the thread is killed while parked here
    end
    assert_equal :started, started.pop(timeout: 10), 'thread never started'
    assert_empty context.exited

    pool.kill

    assert wait_until { !context.exited.empty? }, 'context did not exit on kill'
  end

  class RaisingContext < Temporalio::Worker::ThreadPool::ThreadContext
    def call
      raise 'context failed'
    end
  end

  def test_context_that_raises_kills_only_its_own_thread
    pool = Temporalio::Worker::ThreadPool.new(thread_context: RaisingContext.new)

    # The block never runs, because the context never yielded.
    ran = Queue.new
    _, err = capture_subprocess_io { pool.execute { ran.push(nil) } }

    assert(wait_until { ran.empty? })
    assert_includes err.to_s, 'context failed' if err && !err.empty?
  ensure
    pool&.kill
  end

  def test_base_context_is_abstract
    assert_raises(NotImplementedError) { Temporalio::Worker::ThreadPool::ThreadContext.new.call { nil } }
  end
end
