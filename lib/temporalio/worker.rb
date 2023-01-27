require 'async'
require 'temporalio/bridge'
require 'temporalio/data_converter'
require 'temporalio/runtime'
require 'temporalio/worker/activity_worker'
require 'temporalio/worker/runner'
require 'temporalio/worker/thread_pool_executor'
require 'temporalio/worker/workflow_worker'

module Temporalio
  # Worker to process workflows and/or activities.
  #
  # Once created, workers can be run and shutdown explicitly via {#run} and {#shutdown}.
  class Worker
    # Run multiple workers and wait for them to be shut down.
    #
    # This will not return until shutdown is complete (and all running activities in all workers
    # finished) and will raise if any of the workers raises a fatal error.
    #
    # @param workers [Array<Temporalio::Worker>] A list of the workers to be run.
    # @param shutdown_signals [Array<String>] A list of process signals for the worker to stop on.
    #   This argument can not be used with a custom block.
    #
    # @yield Optionally you can provide a block by the end of which all the workers will be shut
    #   down. Any errors raised from this block will be re-raised by this method.
    def self.run(*workers, shutdown_signals: [], &block)
      unless shutdown_signals.empty?
        if block
          raise ArgumentError, 'Temporalio::Worker.run accepts :shutdown_signals or a block, but not both'
        end

        signal_queue = Queue.new

        shutdown_signals.each do |signal|
          Signal.trap(signal) { signal_queue.close }
        end

        block = -> { signal_queue.pop }
      end

      Runner.new(*workers).run(&block)
    end

    # Create a worker to process workflows and/or activities.
    #
    # @param connection [Temporalio::Connection] A connection to be used for this worker.
    # @param namespace [String] A namespace.
    # @param task_queue [String] A task queue.
    # @param activities [Array<Class>] A list of activities (subclasses of {Temporalio::Activity}).
    # @param workflows [Array<Class>] A list of workflows (subclasses of {Temporalio::Workflow}).
    # @param data_converter [Temporalio::DataConverter] Data converter to use for all data conversions
    #   to/from payloads.
    # @param activity_executor [ThreadPoolExecutor] Concurrent executor for all activities. Defaults
    #   to a {ThreadPoolExecutor} with `:max_concurrent_activities` available threads.
    # @param interceptors [Array<Temporalio::Interceptor::ActivityInbound, Temporalio::Interceptor::ActivityOutbound>]
    #   Collection of interceptors for this worker.
    # @param max_concurrent_activities [Integer] Number of concurrently running activities.
    # @param graceful_shutdown_timeout [Integer] Amount of time (in seconds) activities are given
    #   after a shutdown to complete before they are cancelled. A default value of `nil` means that
    #   activities are never cancelled when handling a shutdown.
    #
    # @raise [ArgumentError] When no activities or workflows have been provided.
    def initialize(
      connection,
      namespace,
      task_queue,
      activities: [],
      workflows: [],
      data_converter: Temporalio::DataConverter.new,
      activity_executor: nil,
      interceptors: [],
      max_concurrent_activities: 100,
      graceful_shutdown_timeout: nil
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
      @activity_worker =
        unless activities.empty?
          Worker::ActivityWorker.new(
            task_queue,
            @core_worker,
            activities,
            data_converter,
            interceptors,
            @activity_executor,
            graceful_shutdown_timeout,
          )
        end
      @workflow_worker =
        unless workflows.empty?
          Worker::WorkflowWorker.new(
            task_queue,
            @core_worker,
            workflows,
            data_converter,
          )
        end

      if !@activity_worker && !@workflow_worker
        raise ArgumentError, 'At least one activity or workflow must be specified'
      end
    end

    # Run the worker and wait on it to be shut down.
    #
    # This will not return until shutdown is complete (and all running activities finished) and will
    # raise if there is a worker fatal error. To run multiple workers use the class method {.run}.
    #
    # @note A worker is only intended to be started once. Initialize a new worker should you need to
    #   run it again.
    #
    # @yield Optionally you can provide a block by the end of which the worker will shut itself
    #   down. You can use this to stop a worker after some time has passed, your workflow has
    #   finished or any other arbitrary implementation has completed. Any errors raised from this
    #   block will be re-raised by this method.
    def run(&block)
      Runner.new(self).run(&block)
    end

    # Start the worker asynchronously in a shared runtime.
    #
    # This is an internal method for advanced use-cases for those intended to implement their own
    # worker runner.
    #
    # @note A worker is only intended to be started once. Initialize a new worker should you need to
    #   start it again.
    #
    # @api private
    #
    # @param runner [Temporalio::Worker::Runner] A runner to notify when the worker is shutting down.
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

        task.async { |task| workflow_worker.run(task) } if workflow_worker
      end
    end

    # Initiate a worker shutdown and wait until complete.
    #
    # This can be called before the worker has even started and is safe for repeated invocations.
    # This method will not return until the worker has completed shutting down.
    #
    # @param exception [Exception] An exception to be raised from {#run} or {.run} methods after a
    #   shutdown procedure has completed.
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

    # Whether the worker has been started.
    #
    # @return [Boolean]
    def started?
      @started
    end

    # Whether the worker is running.
    #
    # This is only `true` if the worker has been started and not yet shut down.
    #
    # @return [Boolean]
    def running?
      @started && !@shutdown
    end

    private

    attr_reader :mutex, :runtime, :activity_executor, :core_worker, :activity_worker,
                :workflow_worker, :runner
  end
end
