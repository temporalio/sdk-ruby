require 'async'
require 'temporalio/bridge'
require 'temporalio/data_converter'
require 'temporalio/runtime'
require 'temporalio/worker/activity_worker'
require 'temporalio/worker/runner'
require 'temporalio/worker/thread_pool_executor'

module Temporalio
  class Worker
    # TODO: Add signal handling
    def self.run(*workers, &block)
      Runner.new(*workers).run(&block)
    end

    # TODO: Add worker interceptors
    def initialize(
      connection,
      namespace,
      task_queue,
      activities: [],
      data_converter: Temporalio::DataConverter.new,
      activity_executor: nil,
      max_concurrent_activities: 100
    )
      @started = false
      @shutdown = false
      @mutex = Mutex.new
      @runtime = Temporalio::Runtime.instance
      @activity_executor = activity_executor || ThreadPoolExecutor.new(max_concurrent_activities)
      @core_worker = Temporalio::Bridge::Worker.create(
        @runtime.core_runtime,
        connection.core_connection,
        namespace,
        task_queue,
      )
      @activity_worker = init_activity_worker(
        task_queue,
        @core_worker,
        activities,
        data_converter,
        @activity_executor,
      )
      @workflow_worker = nil

      if !@activity_worker && !@workflow_worker
        raise ArgumentError, 'At least one activity or workflow must be specified'
      end
    end

    def run(&block)
      Runner.new(self).run(&block)
    end

    def start(runner = nil)
      mutex.synchronize do
        raise 'Worker is already started' if started?

        @started = true
      end

      @runner = runner
      runtime.ensure_callback_loop

      runtime.reactor.async do |task|
        if activity_worker
          task.async do |task|
            activity_worker.run(task)
          rescue StandardError => e
            shutdown(e) # initiate shutdown because of a fatal error
          end
        end

        # TODO: Pending implementation
        task.async { |task| workflow_worker.run(task) } if workflow_worker
      end
    end

    def shutdown(exception = Temporalio::Error::WorkerShutdown.new('Manual shutdown'))
      mutex.synchronize do
        return unless running?

        # First initiate Core shutdown, which will start dropping poll requests
        core_worker.initiate_shutdown
        # Then let the runner know we're shutting down, so it can stop other workers
        runner&.shutdown(exception)
        # Wait for workers to drain any outstanding tasks
        activity_worker&.drain
        workflow_worker&.drain
        # Stop the executor (at this point there should already be nothing in it)
        activity_executor.shutdown
        # Finalize the shutdown by stopping the Core
        core_worker.shutdown

        @shutdown = true
      end
    end

    def started?
      @started
    end

    def running?
      @started && !@shutdown
    end

    private

    attr_reader :mutex, :runtime, :activity_executor, :core_worker, :activity_worker,
                :workflow_worker, :runner

    def init_activity_worker(task_queue, core_worker, activities, data_converter, executor)
      return if activities.empty?

      Worker::ActivityWorker.new(task_queue, core_worker, activities, data_converter, executor)
    end
  end
end
