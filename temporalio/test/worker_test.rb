# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

class WorkerTest < Test
  also_run_all_tests_in_fiber

  class SimpleActivity < Temporalio::Activity::Definition
    def execute(name)
      "Hello, #{name}!"
    end
  end

  def test_run_with_cancellation
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      activities: [SimpleActivity]
    )
    cancellation, cancel_proc = Temporalio::Cancellation.new
    done = Queue.new
    run_in_background do
      # We will test for Thread.raise if threaded
      if Fiber.current_scheduler
        worker.run(cancellation:)
        done.push(nil)
      else
        worker.run(cancellation:) { Queue.new.pop }
      end
    rescue StandardError => e
      done.push(e)
    end
    cancel_proc.call
    err = done.pop
    assert_nil err if Fiber.current_scheduler
    assert_equal 'Workers finished', err.message unless Fiber.current_scheduler
  end

  def test_run_immediately_complete_block
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      activities: [SimpleActivity]
    )
    assert_equal('done', worker.run { 'done' })
  end

  def test_poll_failure_causes_shutdown
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      activities: [SimpleActivity]
    )

    # Run in background
    done = Queue.new
    run_in_background do
      worker.run do
        # Mimic a poll failure
        raise Temporalio::Internal::Worker::MultiRunner::InjectEventForTesting.new( # rubocop:disable Style/RaiseArgs
          Temporalio::Internal::Worker::MultiRunner::Event::PollFailure.new(
            worker:,
            worker_type: :activity,
            error: RuntimeError.new('Intentional error')
          )
        )
      end
    rescue StandardError => e
      done.push(e)
    end
    err = done.pop
    assert_kind_of RuntimeError, err
    assert_equal 'Intentional error', err.message
  end

  def test_block_failure_causes_shutdown
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      activities: [SimpleActivity]
    )

    # Run in background
    done = Queue.new
    run_in_background do
      worker.run  { raise 'Intentional error' }
    rescue StandardError => e
      done.push(e)
    end
    err = done.pop
    assert_kind_of RuntimeError, err
    assert_equal 'Intentional error', err.message
  end

  def test_can_run_with_resource_tuner
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      activities: [SimpleActivity],
      tuner: Temporalio::Worker::Tuner.create_resource_based(target_memory_usage: 0.5, target_cpu_usage: 0.5)
    )
    worker.run do
      env.with_kitchen_sink_worker do |kitchen_sink_task_queue|
        result = env.client.execute_workflow(
          'kitchen_sink',
          { actions: [{ execute_activity: { name: 'SimpleActivity',
                                            task_queue: worker.task_queue,
                                            args: ['Temporal'] } }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue: kitchen_sink_task_queue
        )
        assert_equal 'Hello, Temporal!', result
      end
    end
  end

  def test_can_run_with_composite_tuner
    resource_tuner_options = Temporalio::Worker::Tuner::ResourceBasedTunerOptions.new(
      target_memory_usage: 0.5,
      target_cpu_usage: 0.5
    )
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      activities: [SimpleActivity],
      tuner: Temporalio::Worker::Tuner.new(
        workflow_slot_supplier: Temporalio::Worker::Tuner::SlotSupplier::Fixed.new(5),
        activity_slot_supplier: Temporalio::Worker::Tuner::SlotSupplier::ResourceBased.new(
          tuner_options: resource_tuner_options,
          slot_options: Temporalio::Worker::Tuner::ResourceBasedSlotOptions.new(
            min_slots: 1,
            max_slots: 20,
            ramp_throttle: 0.06
          )
        ),
        local_activity_slot_supplier: Temporalio::Worker::Tuner::SlotSupplier::ResourceBased.new(
          tuner_options: resource_tuner_options,
          slot_options: Temporalio::Worker::Tuner::ResourceBasedSlotOptions.new(
            min_slots: 1,
            max_slots: 5,
            ramp_throttle: 0.06
          )
        )
      )
    )
    worker.run do
      env.with_kitchen_sink_worker do |kitchen_sink_task_queue|
        result = env.client.execute_workflow(
          'kitchen_sink',
          { actions: [{ execute_activity: { name: 'SimpleActivity',
                                            task_queue: worker.task_queue,
                                            args: ['Temporal'] } }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue: kitchen_sink_task_queue
        )
        assert_equal 'Hello, Temporal!', result
      end
    end
  end

  class WaitOnSignalWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { @complete }
      Temporalio::Workflow.execute_activity(
        SimpleActivity,
        'dogg',
        start_to_close_timeout: 10,
        retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
      )
    end

    workflow_signal
    def complete(value)
      @complete = value
    end
  end

  def test_can_run_with_autoscaling_poller_behavior
    prom_addr = "127.0.0.1:#{find_free_port}"
    runtime = Temporalio::Runtime.new(
      telemetry: Temporalio::Runtime::TelemetryOptions.new(
        metrics: Temporalio::Runtime::MetricsOptions.new(
          prometheus: Temporalio::Runtime::PrometheusMetricsOptions.new(
            bind_address: prom_addr
          )
        )
      )
    )
    conn_opts = env.client.connection.options.with(runtime:)
    client_opts = env.client.options.with(
      connection: Temporalio::Client::Connection.new(**conn_opts.to_h) # steep:ignore
    )
    client = Temporalio::Client.new(**client_opts.to_h) # steep:ignore
    worker = Temporalio::Worker.new(
      client: client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [WaitOnSignalWorkflow],
      activities: [SimpleActivity],
      workflow_task_poller_behavior: Temporalio::Worker::PollerBehavior::Autoscaling.new(
        initial: 2
      ),
      activity_task_poller_behavior: Temporalio::Worker::PollerBehavior::Autoscaling.new(
        initial: 2
      )
    )
    worker.run do
      # Give pollers a beat to get started
      sleep(0.3)

      dump = Net::HTTP.get(URI("http://#{prom_addr}/metrics"))
      lines = dump.split("\n")

      matches = lines.select { |l| l.include?('temporal_num_pollers') }
      activity_pollers = matches.select { |l| l.include?('activity_task') }
      assert_equal 1, activity_pollers.size
      assert activity_pollers[0].end_with?('2')

      workflow_pollers = matches.select { |l| l.include?('workflow_task') }
      assert_equal 2, workflow_pollers.size
      # There's sticky & non-sticky pollers, and they may have a count of 1 or 2 depending on
      # initialization timing.
      assert(workflow_pollers[0].end_with?('2') || workflow_pollers[0].end_with?('1'))
      assert(workflow_pollers[1].end_with?('2') || workflow_pollers[1].end_with?('1'))

      handles = Array.new(20) do
        env.client.start_workflow(
          WaitOnSignalWorkflow,
          id: "wf-#{SecureRandom.uuid}",
          task_queue: worker.task_queue
        )
      end
      handles.each do |handle|
        handle.signal(:complete, true)
      end
      handles.each do |handle| # rubocop:disable Style/CombinableLoops
        assert_equal 'Hello, dogg!', handle.result
      end
    end
  end
end
