# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'

class WorkerWorkflowChildTest < Test
  class SimpleChildWorkflow < Temporalio::Workflow::Definition
    def execute(scenario, arg = nil)
      case scenario.to_sym
      when :return
        arg
      when :fail
        raise Temporalio::Error::ApplicationError.new('Intentional failure', 'detail1', 'detail2')
      when :wait
        Temporalio::Workflow.wait_condition { false }
      else
        raise NotImplementedError
      end
    end
  end

  class SimpleParentWorkflow < Temporalio::Workflow::Definition
    def execute(scenario, arg = nil)
      case scenario.to_sym
      when :success
        [
          Temporalio::Workflow.execute_child_workflow(SimpleChildWorkflow, :return, arg),
          Temporalio::Workflow.execute_child_workflow(:SimpleChildWorkflow, :return, arg),
          Temporalio::Workflow.execute_child_workflow('SimpleChildWorkflow', :return, arg)
        ]
      when :fail
        Temporalio::Workflow.execute_child_workflow(SimpleChildWorkflow, :fail)
      when :already_exists
        handle = Temporalio::Workflow.start_child_workflow(SimpleChildWorkflow, :wait)
        Temporalio::Workflow.start_child_workflow(SimpleChildWorkflow, :wait, id: handle.id)
      else
        raise NotImplementedError
      end
    end
  end

  def test_simple
    # Success
    result = execute_workflow(SimpleParentWorkflow, :success, 'val', more_workflows: [SimpleChildWorkflow])
    assert_equal %w[val val val], result

    # Fail
    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(SimpleParentWorkflow, :fail, more_workflows: [SimpleChildWorkflow])
    end
    assert_instance_of Temporalio::Error::ChildWorkflowError, err.cause
    assert_instance_of Temporalio::Error::ApplicationError, err.cause.cause
    assert_equal %w[detail1 detail2], err.cause.cause.details

    # Already exists
    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(SimpleParentWorkflow, :already_exists, more_workflows: [SimpleChildWorkflow])
    end
    assert_instance_of Temporalio::Error::ApplicationError, err.cause
    assert_includes err.cause.message, 'already started'
  end

  class CancelChildWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { false }
    rescue Temporalio::Error::CanceledError
      'done'
    end
  end

  class CancelParentWorkflow < Temporalio::Workflow::Definition
    def execute(scenario)
      case scenario.to_sym
      when :cancel_wait
        cancellation, cancel_proc = Temporalio::Cancellation.new
        handle = Temporalio::Workflow.start_child_workflow(CancelChildWorkflow, cancellation:)
        Temporalio::Workflow.sleep(0.1)
        cancel_proc.call
        handle.result
      when :cancel_try
        cancellation, cancel_proc = Temporalio::Cancellation.new
        handle = Temporalio::Workflow.start_child_workflow(
          CancelChildWorkflow,
          cancellation:,
          cancellation_type: Temporalio::Workflow::ChildWorkflowCancellationType::TRY_CANCEL
        )
        Temporalio::Workflow.sleep(0.1)
        cancel_proc.call
        handle.result
      else
        raise NotImplementedError
      end
    end
  end

  def test_cancel
    # Cancel wait
    assert_equal 'done', execute_workflow(CancelParentWorkflow, :cancel_wait, more_workflows: [CancelChildWorkflow])

    # Cancel try
    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(CancelParentWorkflow, :cancel_try, more_workflows: [CancelChildWorkflow])
    end
    assert_instance_of Temporalio::Error::ChildWorkflowError, err.cause
    assert_instance_of Temporalio::Error::CanceledError, err.cause.cause
  end

  class SignalChildWorkflow < Temporalio::Workflow::Definition
    workflow_query_attr_reader :signals

    def execute(scenario)
      case scenario.to_sym
      when :wait
        Temporalio::Workflow.wait_condition { false }
      when :finish
        'done'
      else
        raise NotImplementedError
      end
    end

    workflow_signal
    def signal(value)
      (@signals ||= []) << value
    end
  end

  class SignalDoNothingActivity < Temporalio::Activity::Definition
    def execute
      # Do nothing
    end
  end

  class SignalParentWorkflow < Temporalio::Workflow::Definition
    def execute(scenario)
      case scenario.to_sym
      when :signal
        handle = Temporalio::Workflow.start_child_workflow(SignalChildWorkflow, :wait)
        handle.signal(SignalChildWorkflow.signal, :foo)
        handle.signal(:signal, :bar)
        handle.id
      when :signal_but_done
        handle = Temporalio::Workflow.start_child_workflow(SignalChildWorkflow, :finish)
        handle.result
        handle.signal(SignalChildWorkflow.signal, :foo)
      when :signal_then_cancel
        handle = Temporalio::Workflow.start_child_workflow(SignalChildWorkflow, :wait)
        cancellation, cancel_proc = Temporalio::Cancellation.new
        Temporalio::Workflow::Future.new do
          Temporalio::Workflow.execute_local_activity(SignalDoNothingActivity, start_to_close_timeout: 10)
          cancel_proc.call
        end
        handle.signal(SignalChildWorkflow.signal, :foo, cancellation:)
      else
        raise NotImplementedError
      end
    end
  end

  def test_signal
    # Successful signals
    execute_workflow(SignalParentWorkflow, :signal, more_workflows: [SignalChildWorkflow]) do |handle|
      child_id = handle.result #: String
      assert_equal %w[foo bar], env.client.workflow_handle(child_id).query(SignalChildWorkflow.signals)
    end

    # Signalling already done
    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(SignalParentWorkflow, :signal_but_done, more_workflows: [SignalChildWorkflow])
    end
    assert_includes err.cause.message, 'not found'

    # Send signal but then cancel in same task
    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(SignalParentWorkflow, :signal_then_cancel,
                       activities: [SignalDoNothingActivity], more_workflows: [SignalChildWorkflow])
    end
    assert_instance_of Temporalio::Error::CanceledError, err.cause
    assert_includes err.cause.message, 'Signal was cancelled'
  end

  class ParentClosePolicyChildWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { @finish }
    end

    workflow_signal
    def finish
      @finish = true
    end
  end

  class ParentClosePolicyParentWorkflow < Temporalio::Workflow::Definition
    def execute(scenario)
      case scenario.to_sym
      when :parent_close_terminate
        handle = Temporalio::Workflow.start_child_workflow(ParentClosePolicyChildWorkflow)
        handle.id
      when :parent_close_request_cancel
        handle = Temporalio::Workflow.start_child_workflow(
          ParentClosePolicyChildWorkflow, parent_close_policy: Temporalio::Workflow::ParentClosePolicy::REQUEST_CANCEL
        )
        handle.id
      when :parent_close_abandon
        handle = Temporalio::Workflow.start_child_workflow(
          ParentClosePolicyChildWorkflow, parent_close_policy: Temporalio::Workflow::ParentClosePolicy::ABANDON
        )
        handle.id
      else
        raise NotImplementedError
      end
    end
  end

  def test_parent_close_policy
    # Terminate
    execute_workflow(ParentClosePolicyParentWorkflow, :parent_close_terminate,
                     more_workflows: [ParentClosePolicyChildWorkflow]) do |handle|
      child_id = handle.result #: String
      err = assert_raises(Temporalio::Error::WorkflowFailedError) do
        env.client.workflow_handle(child_id).result
      end
      assert_instance_of Temporalio::Error::TerminatedError, err.cause
    end

    # Request cancel
    execute_workflow(ParentClosePolicyParentWorkflow, :parent_close_request_cancel,
                     more_workflows: [ParentClosePolicyChildWorkflow]) do |handle|
      child_id = handle.result #: String
      assert_eventually do
        err = assert_raises(Temporalio::Error::WorkflowFailedError) do
          env.client.workflow_handle(child_id).result
        end
        assert_instance_of Temporalio::Error::CanceledError, err.cause
      end
    end

    # Abandon
    execute_workflow(ParentClosePolicyParentWorkflow, :parent_close_abandon,
                     more_workflows: [ParentClosePolicyChildWorkflow]) do |handle|
      child_id = handle.result #: String
      child_handle = env.client.workflow_handle(child_id)
      child_handle.signal(ParentClosePolicyChildWorkflow.finish)
      child_handle.result
    end
  end

  class SearchAttributesChildWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.search_attributes.to_h.transform_keys(&:name)
    end
  end

  class SearchAttributesParentWorkflow < Temporalio::Workflow::Definition
    def execute
      search_attributes = Temporalio::Workflow.search_attributes.dup
      search_attributes[Test::ATTR_KEY_TEXT] = 'changed-text'
      Temporalio::Workflow.execute_child_workflow(SearchAttributesChildWorkflow, search_attributes:)
    end
  end

  def test_search_attributes
    env.ensure_common_search_attribute_keys

    # Unchanged
    results = execute_workflow(
      SearchAttributesParentWorkflow, :unchanged,
      more_workflows: [SearchAttributesChildWorkflow],
      search_attributes: Temporalio::SearchAttributes.new(
        { ATTR_KEY_TEXT => 'some-text', ATTR_KEY_KEYWORD => 'some-keyword' }
      )
    )
    assert_equal({ ATTR_KEY_TEXT.name => 'changed-text', ATTR_KEY_KEYWORD.name => 'some-keyword' }, results)
  end

  class ManyChildrenActivity < Temporalio::Activity::Definition
    def execute(name)
      "Hello #{name}"
    end
  end

  class ManyChildrenChildWorkflow < Temporalio::Workflow::Definition
    def execute(name)
      Temporalio::Workflow.execute_activity(
        ManyChildrenActivity,
        name,
        start_to_close_timeout: 30
      )
    end
  end

  class ManyChildrenWorkflow < Temporalio::Workflow::Definition
    COUNT = 500

    def execute
      futures = ManyChildrenWorkflow::COUNT.times.map do |i|
        Temporalio::Workflow::Future.new do
          Temporalio::Workflow.execute_child_workflow(ManyChildrenChildWorkflow, "Test #{i}")
        end
      end

      Temporalio::Workflow::Future.all_of(*futures).wait

      'done'
    end
  end

  def test_many_children
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      activities: [ManyChildrenActivity],
      workflows: [ManyChildrenWorkflow, ManyChildrenChildWorkflow],
      # This is a slow test, so we need to beef up the tuner and pollers
      tuner: Temporalio::Worker::Tuner.create_fixed(
        workflow_slots: ManyChildrenWorkflow::COUNT + 1,
        activity_slots: ManyChildrenWorkflow::COUNT
      ),
      max_concurrent_workflow_task_polls: 60,
      max_concurrent_activity_task_polls: 60
    )
    worker.run do
      handle = env.client.start_workflow(
        ManyChildrenWorkflow,
        id: "wf-#{SecureRandom.uuid}",
        task_queue: worker.task_queue
      )
      assert_equal('done', handle.result)
      # Confirm there are expected number of child completions
      assert_equal(
        ManyChildrenWorkflow::COUNT,
        handle.fetch_history_events.count(&:child_workflow_execution_completed_event_attributes)
      )
    end
  end
end
