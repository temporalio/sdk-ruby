require 'async'
require 'temporal/bridge'
require 'temporal/data_converter'
require 'temporal/failure_converter'
require 'temporal/payload_converter'
require 'temporal/runtime'
require 'temporal/worker/activity'
require 'temporal/worker/thread_pool_executor'

module Temporal
  class Worker
    # TODO: Add worker interceptors
    def initialize(
      connection,
      namespace,
      task_queue,
      payload_converter: Temporal::PayloadConverter::DEFAULT,
      payload_codecs: [],
      failure_converter: Temporal::FailureConverter::DEFAULT,
      activity_executor: nil,
      max_concurrent_activities: 100
    )
      @running = false
      @mutex = Mutex.new
      @runtime = Temporal::Runtime.instance
      activity_executor ||= ThreadPoolExecutor.new(max_concurrent_activities)
      data_converter = DataConverter.new(
        payload_converter: payload_converter,
        payload_codecs: payload_codecs,
        failure_converter: failure_converter,
      )
      core_worker = Temporal::Bridge::Worker.create(
        @runtime.core_runtime,
        connection.core_connection,
        namespace,
        task_queue,
      )
      @activity_worker = Worker::Activity.new(core_worker, data_converter, activity_executor)
      @workflow_worker = nil
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
  end
end
