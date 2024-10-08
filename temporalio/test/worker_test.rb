# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

class WorkerTest < Test
  also_run_all_tests_in_fiber

  class SimpleActivity < Temporalio::Activity
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
end
