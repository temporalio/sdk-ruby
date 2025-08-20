# frozen_string_literal: true

require 'temporalio/priority'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'

class WorkerWorkflowPriorityTest < Test
  class ActivityWithPriority < Temporalio::Activity::Definition
    def execute(expected_priority, expected_fairness_key = nil, expected_weight = nil)
      info = Temporalio::Activity::Context.current.info
      actual_priority = info.priority&.priority_key
      actual_fairness_key = info.priority&.fairness_key
      actual_weight = info.priority&.fairness_weight
      [actual_priority, expected_priority, actual_fairness_key, expected_fairness_key, actual_weight, expected_weight]
    end
  end

  class WorkflowUsingPriorities < Temporalio::Workflow::Definition
    def float_matches?(expected, actual, tolerance = 0.001)
      return true if expected.nil? && actual.nil?
      return false if expected.nil? || actual.nil?

      (actual - expected).abs <= tolerance
    end

    def execute(expected_priority, stop_after_check, expected_fairness_key = nil, expected_weight = nil)
      info = Temporalio::Workflow.info
      actual_priority = info.priority&.priority_key
      actual_fairness_key = info.priority&.fairness_key
      actual_weight = info.priority&.fairness_weight

      raise "Expected priority #{expected_priority}, got #{actual_priority}" if actual_priority != expected_priority
      if actual_fairness_key != expected_fairness_key
        raise "Expected fairness_key #{expected_fairness_key}, got #{actual_fairness_key}"
      end
      raise "Expected weight #{expected_weight}, got #{actual_weight}" unless float_matches?(expected_weight,
                                                                                             actual_weight)

      return 'Done!' if stop_after_check

      child_result = Temporalio::Workflow.execute_child_workflow(
        'WorkflowUsingPriorities',
        4,
        true,
        'tenant-a',
        2.0,
        priority: Temporalio::Priority.new(priority_key: 4, fairness_key: 'tenant-a', fairness_weight: 2.0)
      )
      raise 'child workflow failed' unless child_result == 'Done!'

      handle = Temporalio::Workflow.start_child_workflow(
        'WorkflowUsingPriorities',
        2,
        true,
        'tenant-b',
        0.5,
        priority: Temporalio::Priority.new(priority_key: 2, fairness_key: 'tenant-b', fairness_weight: 0.5)
      )
      result = handle.result
      raise 'child workflow failed' unless result == 'Done!'

      act_actual, act_expected, act_fairness_actual, act_fairness_expected, act_weight_actual, act_weight_expected = Temporalio::Workflow.execute_activity(
        ActivityWithPriority,
        5,
        'high',
        1.5,
        start_to_close_timeout: 5,
        priority: Temporalio::Priority.new(priority_key: 5, fairness_key: 'high', fairness_weight: 1.5)
      )
      raise "Activity expected priority #{act_expected}, got #{act_actual}" if act_actual != act_expected
      if act_fairness_actual != act_fairness_expected
        raise "Activity expected fairness_key #{act_fairness_expected}, got #{act_fairness_actual}"
      end
      raise "Activity expected weight #{act_weight_expected}, got #{act_weight_actual}" unless float_matches?(
        act_weight_expected, act_weight_actual
      )

      'Done!'
    end
  end

  def test_workflow_priority
    execute_workflow(
      WorkflowUsingPriorities, 1, false, 'tenant-main', 0.8,
      activities: [ActivityWithPriority],
      priority: Temporalio::Priority.new(priority_key: 1, fairness_key: 'tenant-main', fairness_weight: 0.8)
    ) do |handle|
      assert_equal 'Done!', handle.result

      first_child = true
      handle.fetch_history_events.each do |event|
        if event.workflow_execution_started_event_attributes
          priority = event.workflow_execution_started_event_attributes.priority
          assert_equal 1, priority.priority_key
          assert_equal 'tenant-main', priority.fairness_key
          assert_in_delta 0.8, priority.fairness_weight, 0.001
        elsif event.start_child_workflow_execution_initiated_event_attributes
          priority = event.start_child_workflow_execution_initiated_event_attributes.priority
          if first_child
            assert_equal 4, priority.priority_key
            assert_equal 'tenant-a', priority.fairness_key
            assert_in_delta 2.0, priority.fairness_weight, 0.001
            first_child = false
          else
            assert_equal 2, priority.priority_key
            assert_equal 'tenant-b', priority.fairness_key
            assert_in_delta 0.5, priority.fairness_weight, 0.001
          end
        elsif event.activity_task_scheduled_event_attributes
          priority = event.activity_task_scheduled_event_attributes.priority
          assert_equal 5, priority.priority_key
          assert_equal 'high', priority.fairness_key
          assert_in_delta 1.5, priority.fairness_weight, 0.001
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

    # Test with only fairness key and weight (no priority_key)
    execute_workflow(
      WorkflowUsingPriorities, nil, true, 'low', 0.2,
      activities: [ActivityWithPriority],
      priority: Temporalio::Priority.new(priority_key: nil, fairness_key: 'low', fairness_weight: 0.2)
    ) do |handle|
      assert_equal 'Done!', handle.result

      handle.fetch_history_events.each do |event|
        next unless event.workflow_execution_started_event_attributes

        priority = event.workflow_execution_started_event_attributes.priority
        assert_equal 0, priority.priority_key # Proto uses 0 for unset
        assert_equal 'low', priority.fairness_key
        assert_in_delta 0.2, priority.fairness_weight, 0.001
      end
    end
  end
end
