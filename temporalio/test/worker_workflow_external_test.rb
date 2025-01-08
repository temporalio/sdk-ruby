# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test_base'

class WorkerWorkflowExternalTest < TestBase
  class ExternalWaitingWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :signals

    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_signal
    def signal(value)
      (@signals ||= []) << value
    end
  end

  class ExternalDoNothingActivity < Temporalio::Activity::Definition
    def execute
      # Do nothing
    end
  end

  class ExternalWorkflow < Temporalio::Workflow::Definition
    def execute(scenario, external_id)
      handle = Temporalio::Workflow.external_workflow_handle(external_id)
      case scenario.to_sym
      when :signal
        handle.signal(ExternalWaitingWorkflow.signal, :foo)
        handle.signal(:signal, :bar)
      when :signal_then_cancel
        cancellation, cancel_proc = Temporalio::Cancellation.new
        Temporalio::Workflow::Future.new do
          Temporalio::Workflow.execute_local_activity(ExternalDoNothingActivity, start_to_close_timeout: 10)
          cancel_proc.call
        end
        handle.signal(ExternalWaitingWorkflow.signal, :foo, cancellation:)
      when :cancel
        handle.cancel
      else
        raise NotImplementedError
      end
    end
  end

  def test_signal
    # Start an external workflow
    execute_workflow(ExternalWaitingWorkflow,
                     more_workflows: [ExternalWorkflow], activities: [ExternalDoNothingActivity]) do |handle, worker|
      # Now run workflow to send the signals
      env.client.execute_workflow(ExternalWorkflow, :signal, handle.id,
                                  id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue)
      # Confirm they were sent
      assert_equal %w[foo bar], handle.query(ExternalWaitingWorkflow.signals)

      # Check ID that does not exist
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        env.client.execute_workflow(ExternalWorkflow, :signal, 'does-not-exist',
                                    id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue)
      end
      assert_includes err.cause.message, 'not found'

      # Send signal but then cancel in same task
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        env.client.execute_workflow(ExternalWorkflow, :signal_then_cancel, handle.id,
                                    id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue)
      end
      assert_instance_of Temporalio::Error::CanceledError, err.cause
      assert_includes err.cause.message, 'Signal was cancelled'
    end
  end

  def test_cancel
    # Start an external workflow
    execute_workflow(ExternalWaitingWorkflow, more_workflows: [ExternalWorkflow]) do |handle, worker|
      # Now run workflow to perform cancel
      env.client.execute_workflow(ExternalWorkflow, :cancel, handle.id,
                                  id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue)
      # Confirm canceled
      err = assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
      assert_instance_of Temporalio::Error::CanceledError, err.cause

      # Check ID that does not exist
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        env.client.execute_workflow(ExternalWorkflow, :cancel, 'does-not-exist',
                                    id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue)
      end
      assert_includes err.cause.message, 'not found'
    end
  end
end
