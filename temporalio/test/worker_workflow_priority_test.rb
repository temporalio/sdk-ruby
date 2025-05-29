# frozen_string_literal: true

require 'temporalio/priority'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'

class WorkerWorkflowPriorityTest < Test
  class ActivityWithPriority < Temporalio::Activity::Definition
    def execute(expected_priority)
      actual_priority = Temporalio::Activity::Context.current.info.priority&.priority_key
      [actual_priority, expected_priority]
    end
  end

  class WorkflowUsingPriorities < Temporalio::Workflow::Definition
    def execute(expected_priority, stop_after_check)
      actual_priority = Temporalio::Workflow.info.priority&.priority_key
      raise "Expected priority #{expected_priority}, got #{actual_priority}" if actual_priority != expected_priority

      return 'Done!' if stop_after_check

      child_result = Temporalio::Workflow.execute_child_workflow(
        'WorkflowUsingPriorities',
        4,
        true,
        priority: Temporalio::Priority.new(priority_key: 4)
      )
      raise 'child workflow failed' unless child_result == 'Done!'

      handle = Temporalio::Workflow.start_child_workflow(
        'WorkflowUsingPriorities',
        2,
        true,
        priority: Temporalio::Priority.new(priority_key: 2)
      )
      result = handle.result
      raise 'child workflow failed' unless result == 'Done!'

      act_actual, act_expected = Temporalio::Workflow.execute_activity(
        ActivityWithPriority,
        5,
        start_to_close_timeout: 5,
        priority: Temporalio::Priority.new(priority_key: 5)
      )
      raise "Activity expected priority #{act_expected}, got #{act_actual}" if act_actual != act_expected

      'Done!'
    end
  end

  def test_workflow_priority
    execute_workflow(
      WorkflowUsingPriorities, 1, false,
      activities: [ActivityWithPriority], priority: Temporalio::Priority.new(priority_key: 1)
    ) do |handle|
      assert_equal 'Done!', handle.result

      first_child = true
      handle.fetch_history_events.each do |event|
        if event.workflow_execution_started_event_attributes
          assert_equal 1, event.workflow_execution_started_event_attributes.priority.priority_key
        elsif event.start_child_workflow_execution_initiated_event_attributes
          if first_child
            assert_equal 4, event.start_child_workflow_execution_initiated_event_attributes.priority.priority_key
            first_child = false
          else
            assert_equal 2, event.start_child_workflow_execution_initiated_event_attributes.priority.priority_key
          end
        elsif event.activity_task_scheduled_event_attributes
          assert_equal 5, event.activity_task_scheduled_event_attributes.priority.priority_key
        end
      end
    end

    # Run workflow without priority
    execute_workflow(
      WorkflowUsingPriorities, nil, true,
      activities: [ActivityWithPriority]
    ) do |handle|
      assert_equal 'Done!', handle.result
    end
  end
end
