# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test_base'

class WorkerWorkflowActivityTest < TestBase
  class SimpleActivity < Temporalio::Activity::Definition
    def execute(value)
      "from activity: #{value}"
    end
  end

  class SimpleWorkflow < Temporalio::Workflow::Definition
    def execute(scenario)
      case scenario.to_sym
      when :remote
        Temporalio::Workflow.execute_activity(SimpleActivity, 'remote', start_to_close_timeout: 10)
      when :remote_symbol_name
        Temporalio::Workflow.execute_activity(:SimpleActivity, 'remote', start_to_close_timeout: 10)
      when :remote_string_name
        Temporalio::Workflow.execute_activity('SimpleActivity', 'remote', start_to_close_timeout: 10)
      when :local
        Temporalio::Workflow.execute_local_activity(SimpleActivity, 'local', start_to_close_timeout: 10)
      when :local_symbol_name
        Temporalio::Workflow.execute_local_activity(:SimpleActivity, 'local', start_to_close_timeout: 10)
      when :local_string_name
        Temporalio::Workflow.execute_local_activity('SimpleActivity', 'local', start_to_close_timeout: 10)
      else
        raise NotImplementedError
      end
    end
  end

  def test_simple
    assert_equal 'from activity: remote',
                 execute_workflow(SimpleWorkflow, :remote, activities: [SimpleActivity])
    assert_equal 'from activity: remote',
                 execute_workflow(SimpleWorkflow, :remote_symbol_name, activities: [SimpleActivity])
    assert_equal 'from activity: remote',
                 execute_workflow(SimpleWorkflow, :remote_string_name, activities: [SimpleActivity])
    assert_equal 'from activity: local',
                 execute_workflow(SimpleWorkflow, :local, activities: [SimpleActivity])
    assert_equal 'from activity: local',
                 execute_workflow(SimpleWorkflow, :local_symbol_name, activities: [SimpleActivity])
    assert_equal 'from activity: local',
                 execute_workflow(SimpleWorkflow, :local_string_name, activities: [SimpleActivity])
  end

  class FailureActivity < Temporalio::Activity::Definition
    def execute
      raise Temporalio::Error::ApplicationError.new('Intentional error', 'detail1', 'detail2', non_retryable: true)
    end
  end

  class FailureWorkflow < Temporalio::Workflow::Definition
    def execute(local)
      if local
        Temporalio::Workflow.execute_local_activity(FailureActivity, start_to_close_timeout: 10)
      else
        Temporalio::Workflow.execute_activity(FailureActivity, start_to_close_timeout: 10)
      end
    end
  end

  def test_failure
    # Most activity failure testing is already part of activity tests, this is just for checking it's propagated

    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(FailureWorkflow, false, activities: [FailureActivity])
    end
    assert_instance_of Temporalio::Error::ActivityError, err.cause
    assert_instance_of Temporalio::Error::ApplicationError, err.cause.cause
    assert_equal %w[detail1 detail2], err.cause.cause.details

    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(FailureWorkflow, true, activities: [FailureActivity])
    end
    assert_instance_of Temporalio::Error::ApplicationError, err.cause
    assert_equal %w[detail1 detail2], err.cause.details
  end

  class CancellationSleepActivity < Temporalio::Activity::Definition
    def execute(amount)
      sleep(amount)
    end
  end

  class CancellationActivity < Temporalio::Activity::Definition
    attr_reader :started, :done

    def initialize
      @queue = Queue.new
    end

    def execute
      @started = true
      # Heartbeat every 100ms
      loop do
        Temporalio::Activity::Context.current.heartbeat
        val = @queue.pop(timeout: 0.1)
        if val
          @done = :success
          return val
        end
      end
    rescue Temporalio::Error::CanceledError
      @done ||= :canceled
      sleep(0.1)
      'cancel swallowed'
    ensure
      @done ||= :failure # rubocop:disable Naming/MemoizedInstanceVariableName
    end

    def force_complete(value)
      @queue << value
    end
  end

  class CancellationWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_update
    def run(scenario, local)
      cancellation_type = case scenario.to_sym
                          when :try_cancel
                            Temporalio::Workflow::ActivityCancellationType::TRY_CANCEL
                          when :wait_cancel
                            Temporalio::Workflow::ActivityCancellationType::WAIT_CANCELLATION_COMPLETED
                          when :abandon
                            Temporalio::Workflow::ActivityCancellationType::ABANDON
                          else
                            raise NotImplementedError
                          end
      # Start
      cancellation, cancel_proc = Temporalio::Cancellation.new
      fut = Temporalio::Workflow::Future.new do
        if local
          Temporalio::Workflow.execute_local_activity(CancellationActivity,
                                                      schedule_to_close_timeout: 10,
                                                      cancellation:,
                                                      cancellation_type:)
        else
          Temporalio::Workflow.execute_activity(CancellationActivity,
                                                schedule_to_close_timeout: 10,
                                                heartbeat_timeout: 5,
                                                cancellation:,
                                                cancellation_type:)
        end
      end

      # Wait a bit then cancel
      if local
        Temporalio::Workflow.execute_local_activity(CancellationSleepActivity, 0.1,
                                                    schedule_to_close_timeout: 10)
      else
        sleep(0.1)
      end
      cancel_proc.call

      fut.wait
    end
  end

  def test_cancellation
    [true, false].each do |local|
      # Try cancel
      # TODO(cretz): This is not working for local because worker shutdown hangs when local activity completes after
      # shutdown started
      unless local
        act = CancellationActivity.new
        execute_workflow(CancellationWorkflow, activities: [act, CancellationSleepActivity],
                                               max_heartbeat_throttle_interval: 0.2,
                                               task_timeout: 3) do |handle|
          update_handle = handle.start_update(
            CancellationWorkflow.run, :try_cancel, local,
            wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
          )
          err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) { update_handle.result }
          assert_instance_of Temporalio::Error::ActivityError, err.cause
          assert_instance_of Temporalio::Error::CanceledError, err.cause.cause
          assert_eventually { assert_equal :canceled, act.done }
        end
      end

      # Wait cancel
      act = CancellationActivity.new
      execute_workflow(CancellationWorkflow, activities: [act, CancellationSleepActivity],
                                             max_heartbeat_throttle_interval: 0.2,
                                             task_timeout: 3) do |handle|
        update_handle = handle.start_update(
          CancellationWorkflow.run, :wait_cancel, local,
          wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
        )
        # assert_eventually { assert act.started }
        # handle.signal(CancellationWorkflow.cancel)
        assert_equal 'cancel swallowed', update_handle.result
        assert_equal :canceled, act.done
      end

      # Abandon cancel
      act = CancellationActivity.new
      execute_workflow(CancellationWorkflow, activities: [act, CancellationSleepActivity],
                                             max_heartbeat_throttle_interval: 0.2,
                                             task_timeout: 3) do |handle|
        update_handle = handle.start_update(
          CancellationWorkflow.run, :abandon, local,
          wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
        )
        # assert_eventually { assert act.started }
        # handle.signal(CancellationWorkflow.cancel)
        err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) { update_handle.result }
        assert_instance_of Temporalio::Error::ActivityError, err.cause
        assert_instance_of Temporalio::Error::CanceledError, err.cause.cause
        assert_nil act.done
        sleep(0.2)
        act.force_complete 'manually complete'
        assert_eventually { assert_equal :success, act.done }
      end
    end
  end

  class LocalBackoffActivity < Temporalio::Activity::Definition
    def execute
      # Succeed on the third attempt
      return 'done' if Temporalio::Activity::Context.current.info.attempt == 3

      raise 'Intentional failure'
    end
  end

  class LocalBackoffWorkflow < Temporalio::Workflow::Definition
    def execute
      # Give a fixed retry of every 200ms, but with a local threshold of 100ms
      Temporalio::Workflow.execute_local_activity(
        LocalBackoffActivity,
        schedule_to_close_timeout: 30,
        local_retry_threshold: 0.1,
        retry_policy: Temporalio::RetryPolicy.new(initial_interval: 0.2, backoff_coefficient: 1)
      )
    end
  end

  def test_local_backoff
    execute_workflow(LocalBackoffWorkflow, activities: [LocalBackoffActivity]) do |handle|
      assert_equal 'done', handle.result
      # Make sure there were two 200ms timers
      assert_equal(2, handle.fetch_history_events.count do |e|
        e.timer_started_event_attributes&.start_to_fire_timeout&.to_f == 0.2 # rubocop:disable Lint/FloatComparison
      end)
    end
  end
end
