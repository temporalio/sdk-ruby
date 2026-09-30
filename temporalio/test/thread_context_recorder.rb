# frozen_string_literal: true

require 'temporalio/worker/thread_pool'

# Thread context for tests: sets a thread-local for the lifetime of each pool thread and clears it
# on the way out, so work running on that thread can observe it and a test can observe the
# teardown. `entered`, `returned` and `exited` are queues because they are pushed to from pool
# threads, which outlive the work they run.
#
# `returned` records reaching the statement after the `yield`, which only happens when the block
# returns normally -- not when the thread is killed inside it.
class ThreadContextRecorder < Temporalio::Worker::ThreadPool::ThreadContext
  VALUE_KEY = :thread_context_value

  attr_reader :entered, :returned, :exited

  def initialize(value: 'acquired')
    super()
    @value = value
    @entered = Queue.new
    @returned = Queue.new
    @exited = Queue.new
  end

  def call
    Thread.current[VALUE_KEY] = @value
    @entered.push(Thread.current.name)
    yield
    @returned.push(Thread.current.name)
  ensure
    Thread.current[VALUE_KEY] = nil
    @exited.push(Thread.current.name)
  end
end
