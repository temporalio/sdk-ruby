require 'async'
require 'temporal/bridge'
require 'temporal/data_converter'
require 'temporal/runtime'
require 'temporal/worker/activity_worker'
require 'temporal/worker/thread_pool_executor'

module Temporal
  class Worker
    # TODO: Add worker interceptors
    def initialize(
      connection,
      namespace,
      task_queue,
      activities: [],
      data_converter: Temporal::DataConverter.new,
      activity_executor: nil,
      max_concurrent_activities: 100
    )
      @running = false
      @mutex = Mutex.new
      @runtime = Temporal::Runtime.instance
      activity_executor ||= ThreadPoolExecutor.new(max_concurrent_activities)
      core_worker = Temporal::Bridge::Worker.create(
        @runtime.core_runtime,
        connection.core_connection,
        namespace,
        task_queue,
      )
      @activity_worker = init_activity_worker(
        task_queue,
        core_worker,
        activities,
        data_converter,
        activity_executor,
      )
      @workflow_worker = nil

      if !@activity_worker && !@workflow_worker
        raise ArgumentError, 'At least one activity or workflow must be specified'
      end
    end

    def run
      Async { |task| start(task) }
    end

    def start(reactor = nil)
      mutex.synchronize do
        raise 'Worker is already running' if running?

        @running = true
      end

      runtime.ensure_callback_loop
      reactor ||= runtime.reactor
      reactor.async { |task| activity_worker.run(task) } if activity_worker
      reactor.async { |task| workflow_worker.run(task) } if workflow_worker
    end

    def shutdown
      activity_worker&.shutdown
      workflow_worker&.shutdown
    end

    private

    attr_reader :mutex, :runtime, :activity_worker, :workflow_worker

    def running?
      @running
    end

    def init_activity_worker(task_queue, core_worker, activities, data_converter, executor)
      return if activities.empty?

      Worker::ActivityWorker.new(task_queue, core_worker, activities, data_converter, executor)
    end
  end
end
