require 'temporal/sdk/core/core_interface_pb'
require 'temporal/bridge'
require 'temporal/runtime'
require 'temporal/async_reactor'
require 'temporal/executors'

module Temporal
  class Worker
    class AlreadyStarted < StandardError; end

    # TODO: Would be better to inject the core worker here to not rely on the strong
    # dependency here. Would make testing easier
    def initialize(connection, namespace, task_queue, reactor = AsyncReactor.new, executor = Executors.new)
      runtime = Temporal::Runtime.instance
      runtime.ensure_callback_loop

      @reactor = reactor
      @running = false
      @executor = executor
      @core_worker = Temporal::Bridge::Worker.create(
        runtime.core_runtime,
        connection.core_connection,
        namespace,
        task_queue
      )
    end

    # TODO: Handle signal traps
    #
    def run
      @running = true

      reactor.async do
        # TODO: Maybe for unit tests to not run the loop but only run once?
        while running?
          activity_task = reactor.sync { poll_activity_task }

          # TODO: Do we need any throttling here?
          reactor.async { process_activity_task(activity_task) }
        end
      end
    end

    # TODO: Do we need to clear any tasks here?
    def terminate
      reactor.terminate
      executor.terminate
      @running = false
    end

    private

    attr_reader :core_worker, :reactor, :executor

    def running?
      @running
    end

    def poll_activity_task
      core_worker.poll_activity_task do |task|
        Coresdk::ActivityTask::ActivityTask.decode(task)
      end
    end

    def process_activity_task(task)
      executor.execute(task)
    end
  end
end
