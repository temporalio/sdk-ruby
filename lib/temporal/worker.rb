require 'temporal/sdk/core/core_interface_pb'
require 'temporal/bridge'
require 'temporal/runtime'
require 'temporal/worker/reactor'

module Temporal
  class Worker
    class AlreadyStarted < StandardError; end

    def initialize(connection, namespace, task_queue)
      runtime = Temporal::Runtime.instance
      runtime.ensure_callback_loop

      @running = false
      @core_worker = Temporal::Bridge::Worker.create(
        runtime.core_runtime,
        connection.core_connection,
        namespace,
        task_queue,
      )
    end

    def run
      start
      Reactor.attach
    end

    def start
      raise AlreadyStarted if running?

      @running = true

      Reactor.execute do |reactor|
        while running?
          task = reactor.await { |r| poll_activity_task(r) }
          reactor.async { |r| process_activity_task(task, r) }
        end
      end
    end

    def shutdown
      @running = false
    end

    private

    attr_reader :core_worker

    def running?
      @running
    end

    def poll_activity_task(resolver)
      core_worker.poll_activity_task do |task|
        decoded_task = Coresdk::ActivityTask::ActivityTask.decode(task)
        resolver.call(decoded_task)
      end
    end

    def process_activity_task(task, resolver)
      puts "Processing #{task.start&.workflow_execution&.run_id} | #{task&.start&.activity_id}"

      # TODO: Will be replaced with an actual processing logic using a thread loop
      Thread.new do
        puts "Processed #{task.start&.workflow_execution&.run_id} | #{task.start&.activity_id}"
        resolver.call
      end
    end
  end
end
