# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

class WorkerTest < Test
  # also_run_all_tests_in_fiber

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
      assert_eventually do
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
      end

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

  class BasicPermit < Object; end

  class TrackingSlotSupplier < Temporalio::Worker::Tuner::SlotSupplier::Custom
    attr_reader :events

    def reserve_slot(context, _cancellation, &)
      add_event(:reserve_slot, context)
      yield BasicPermit.new
    end

    def try_reserve_slot(context)
      add_event(:try_reserve_slot, context)
      BasicPermit.new
    end

    def mark_slot_used(context)
      add_event(:mark_slot_used, context)
    end

    def release_slot(context)
      add_event(:release_slot, context)
    end

    private

    def add_event(method, context)
      (@events ||= []) << [method, context]
    end
  end

  class SlotSupplierActivity < Temporalio::Activity::Definition
    def execute; end
  end

  class SlotSupplierWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.execute_activity(SlotSupplierActivity, start_to_close_timeout: 10)
      Temporalio::Workflow.execute_local_activity(SlotSupplierActivity, start_to_close_timeout: 10)
    end
  end

  def test_custom_slot_supplier_simple
    supplier = TrackingSlotSupplier.new
    execute_workflow(
      SlotSupplierWorkflow,
      activities: [SlotSupplierActivity],
      tuner: Temporalio::Worker::Tuner.new(
        workflow_slot_supplier: supplier,
        activity_slot_supplier: supplier,
        local_activity_slot_supplier: supplier
      )
    )
    # Assert the events are as expected...
    events = supplier.events

    # Had to get reserved for workflow (sticky and non), activity, and local activity
    assert(events.any? { |(m, e)| m == :reserve_slot && e.slot_type == :workflow && !e.sticky? })
    assert(events.any? { |(m, e)| m == :reserve_slot && e.slot_type == :workflow && e.sticky? })
    assert(events.any? { |(m, e)| m == :reserve_slot && e.slot_type == :activity })
    assert(events.any? { |(m, e)| m == :reserve_slot && e.slot_type == :local_activity })

    # Since the activity was eager, had to get a try reserve for it
    assert(events.any? { |(m, e)| m == :try_reserve_slot && e.slot_type == :activity })

    # # Had to get mark used for workflow (sticky and non), activity, and local activity
    assert(events.any? do |(m, e)|
      m == :mark_slot_used && e.slot_info.is_a?(Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Workflow) &&
        e.slot_info.workflow_type == 'SlotSupplierWorkflow' && !e.slot_info.sticky? && e.permit.is_a?(BasicPermit)
    end)
    assert(events.any? do |(m, e)|
      m == :mark_slot_used && e.slot_info.is_a?(Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Workflow) &&
        e.slot_info.workflow_type == 'SlotSupplierWorkflow' && e.slot_info.sticky? && e.permit.is_a?(BasicPermit)
    end)
    assert(events.any? do |(m, e)|
      m == :mark_slot_used && e.slot_info.is_a?(Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Activity) &&
        e.slot_info.activity_type == 'SlotSupplierActivity' && e.permit.is_a?(BasicPermit)
    end)
    assert(events.any? do |(m, e)|
      m == :mark_slot_used &&
        e.slot_info.is_a?(Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::LocalActivity) &&
        e.permit.is_a?(BasicPermit)
      # TODO(cretz): Uncomment once https://github.com/temporalio/sdk-core/issues/1016 resolved
      # && e.slot_info.activity_type == 'SlotSupplierActivity'
    end)

    # Must be a release for every reserve
    assert_equal(
      events.count { |(m, _)| m == :reserve_slot || m == :try_reserve_slot },
      events.count { |(m, _)| m == :release_slot }
    )
  end

  class BlockingSlotSupplier < Temporalio::Worker::Tuner::SlotSupplier::Custom
    attr_reader :canceled_contexts

    def reserve_slot(context, cancellation, &)
      # We'll block on every reserve, waiting for queue to get resolved
      queue = Queue.new
      (@waiting ||= []) << [context, queue]
      cancellation.add_cancel_callback do
        (@canceled_contexts ||= []) << context
        queue.push(StandardError.new('Canceled'))
      end
      yield queue.pop
    end

    def try_reserve_slot(_context)
      # No try-reserve
      None
    end

    def mark_slot_used(_context)
      # Do nothing
    end

    def release_slot(_context)
      # Do nothing
    end

    def resolve_a_reserve(slot_type)
      waiting_idx = @waiting&.index { |(context, _)| context.slot_type == slot_type }
      raise 'Not found' unless waiting_idx

      _, queue = @waiting.delete_at(waiting_idx)
      queue << BasicPermit.new
    end

    def waiting_contexts
      @waiting.map(&:first)
    end
  end

  class BlockingSlotSupplierWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.execute_activity(SlotSupplierActivity, start_to_close_timeout: 10)
    end
  end

  def test_custom_slot_supplier_blocking
    supplier = BlockingSlotSupplier.new
    waiting_contexts = execute_workflow(
      BlockingSlotSupplierWorkflow,
      activities: [SlotSupplierActivity],
      tuner: Temporalio::Worker::Tuner.new(
        workflow_slot_supplier: supplier,
        activity_slot_supplier: supplier,
        local_activity_slot_supplier: supplier
      ),
      # Core does not progress if you don't let sticky be reserved, and we want to manually control every slot
      max_cached_workflows: 0
    ) do |handle|
      # Make sure history has not started a task
      assert handle.fetch_history_events.none?(&:workflow_task_started_event_attributes)
      # Let one reserve call for workflow task through
      supplier.resolve_a_reserve(:workflow)
      # Make sure history has a task completed
      assert_eventually { assert handle.fetch_history_events.any?(&:workflow_task_completed_event_attributes) }

      # Now resolve one activity and wait for history to show activity completion
      supplier.resolve_a_reserve(:activity)
      assert_eventually { assert handle.fetch_history_events.any?(&:activity_task_completed_event_attributes) }

      # Now resolve one workflow task to let that progress
      supplier.resolve_a_reserve(:workflow)

      # Confirm the workflow completes successfully
      handle.result

      # Collect the waiting contexts
      supplier.waiting_contexts
    end

    # Confirm we canceled all waiting reservations
    assert_equal waiting_contexts.size, supplier.canceled_contexts.size
    waiting_contexts.each { |w| assert_includes supplier.canceled_contexts, w }
  end

  class RaisingSlotSupplier < Temporalio::Worker::Tuner::SlotSupplier::Custom
    def reserve_slot(context, _cancellation, &)
      # We'll only raise on non-workflows
      raise 'Intentional error' unless context.slot_type == :workflow

      yield BasicPermit.new
    end

    def try_reserve_slot(_context)
      raise 'Intentional error'
    end

    def mark_slot_used(_context)
      raise 'Intentional error'
    end

    def release_slot(_context)
      raise 'Intentional error'
    end
  end

  class SlotSupplierRaisingWorkflow < Temporalio::Workflow::Definition
    def execute
      'done'
    end
  end

  def test_custom_slot_supplier_raising
    supplier = RaisingSlotSupplier.new
    assert_equal 'done', execute_workflow(
      SlotSupplierRaisingWorkflow,
      tuner: Temporalio::Worker::Tuner.new(
        workflow_slot_supplier: supplier,
        activity_slot_supplier: supplier,
        local_activity_slot_supplier: supplier
      )
    )
  end
end
