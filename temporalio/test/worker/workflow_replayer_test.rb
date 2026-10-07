# frozen_string_literal: true

require 'temporalio/activity'
require 'temporalio/worker/workflow_replayer'
require 'temporalio/workflow'
require 'temporalio/workflow_history'
require 'test'

module Worker
  class WorkflowReplayerTest < Test
    class SayHelloActivity < Temporalio::Activity::Definition
      def execute(name)
        "Hello, #{name}!"
      end
    end

    class SayHelloWorkflow < Temporalio::Workflow::Definition
      workflow_query_attr_reader :waiting

      def execute(params)
        result = Temporalio::Workflow.execute_activity(
          SayHelloActivity, params['name'],
          schedule_to_close_timeout: 10
        )

        # Wait if requested
        if params['should_hang']
          @waiting = true
          Temporalio::Workflow.wait_condition { false }
        end

        # Raise if requested
        raise Temporalio::Error::ApplicationError, 'Intentional error' if params['should_error']
        raise 'Intentional task failure' if params['should_fail_task']

        # Cause non-determinism if requested
        if params['should_cause_non_determinism'] && Temporalio::Workflow::Unsafe.replaying?
          Temporalio::Workflow.sleep(0.1)
        end

        result
      end
    end

    def test_simple
      # Run simple workflow to completion and get history
      history = execute_workflow(SayHelloWorkflow, { name: 'Temporal' }, activities: [SayHelloActivity]) do |handle|
        assert_equal 'Hello, Temporal!', handle.result
        handle.fetch_history
      end

      # Confirm conversion to/from json
      history_json = history.to_history_json
      assert_equal history, Temporalio::WorkflowHistory.from_history_json(history_json)

      # Replay history in various ways
      assert_nil Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow])
                                                     .replay_workflow(history)
                                                     .replay_failure
      assert_nil Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow])
                                                     .replay_workflows([history])
                                                     .first #: Temporalio::Worker::WorkflowReplayer::ReplayResult
                                                     .replay_failure
      assert_nil Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow])
                                                     .replay_workflows(Enumerator.new { |y| y << history })
                                                     .first #: Temporalio::Worker::WorkflowReplayer::ReplayResult
                                                     .replay_failure
      Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow]) do |w|
        assert_nil w.replay_workflow(history).replay_failure
      end
      assert_nil Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow])
                                                     .with_replay_worker { |w| w.replay_workflow(history) }
                                                     .replay_failure
      histories = env.client
                     .list_workflows("WorkflowId = '#{history.workflow_id}'")
                     .map { |e| env.client.workflow_handle(e.id).fetch_history }
      assert_nil Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow])
                                                     .replay_workflows(histories)
                                                     .first #: Temporalio::Worker::WorkflowReplayer::ReplayResult
                                                     .replay_failure
    end

    def test_incomplete_run
      # Start simple workflow and get history
      history = execute_workflow(
        SayHelloWorkflow, { name: 'Temporal', should_hang: true }, activities: [SayHelloActivity]
      ) do |handle|
        # Wait until "waiting" to get history
        assert_eventually { assert handle.query(SayHelloWorkflow.waiting) }
        handle.fetch_history
      end
      # Replay
      assert_nil Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow])
                                                     .replay_workflow(history)
                                                     .replay_failure
    end

    def test_failed_run
      # Run to failure and get history
      history = execute_workflow(
        SayHelloWorkflow, { name: 'Temporal', should_error: true }, activities: [SayHelloActivity]
      ) do |handle|
        assert_raises(Temporalio::Error::WorkflowFailedError) { handle.result }
        handle.fetch_history
      end
      # Replay
      assert_nil Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow])
                                                     .replay_workflow(history)
                                                     .replay_failure
    end

    def test_non_deterministic_run
      # Run to completion and get history
      history = execute_workflow(
        SayHelloWorkflow, { name: 'Temporal', should_cause_non_determinism: true }, activities: [SayHelloActivity]
      ) do |handle|
        assert_equal 'Hello, Temporal!', handle.result
        handle.fetch_history
      end

      # Confirm replay raises non-determinism
      assert_raises(Temporalio::Workflow::NondeterminismError) do
        Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow]).replay_workflow(history)
      end

      # And returns if not asked to raise
      assert_instance_of Temporalio::Workflow::NondeterminismError,
                         Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow])
                                                             .replay_workflow(history, raise_on_replay_failure: false)
                                                             .replay_failure
    end

    def test_task_failure
      # Run to failure and get history
      history = execute_workflow(
        SayHelloWorkflow, { name: 'Temporal', should_fail_task: true }, activities: [SayHelloActivity]
      ) do |handle|
        assert_eventually_task_fail(handle:)
        handle.fetch_history
      end
      # Replay
      assert_nil Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow])
                                                     .replay_workflow(history)
                                                     .replay_failure
    end

    def test_multiple_histories
      # Run simple workflow to completion and get history
      history1 = execute_workflow(SayHelloWorkflow, { name: 'Temporal' }, activities: [SayHelloActivity]) do |handle|
        assert_equal 'Hello, Temporal!', handle.result
        handle.fetch_history
      end
      # Run non-deterministic to completion and get history
      history2 = execute_workflow(
        SayHelloWorkflow, { name: 'Temporal', should_cause_non_determinism: true }, activities: [SayHelloActivity]
      ) do |handle|
        assert_equal 'Hello, Temporal!', handle.result
        handle.fetch_history
      end
      results = Temporalio::Worker::WorkflowReplayer.new(workflows: [SayHelloWorkflow])
                                                    .replay_workflows([history1, history2])
      assert_equal 2, results.size
      assert_nil results.first&.replay_failure # steep:ignore
      assert_instance_of Temporalio::Workflow::NondeterminismError, results.last&.replay_failure
    end

    class ChildStartFailureWorkflow < Temporalio::Workflow::Definition
      def execute(expected_cause)
        Temporalio::Workflow.start_child_workflow('child-workflow', id: 'child-id')
        raise 'Child workflow unexpectedly started'
      rescue Temporalio::Error::ChildWorkflowError, Temporalio::Error::WorkflowAlreadyStartedError => e
        failure = expected_cause == 'Temporalio::Error::WorkflowAlreadyStartedError' ? e : e.cause
        unless failure.instance_of?(Object.const_get(expected_cause))
          raise "Unexpected child start failure: #{e.inspect}, cause: #{e.cause.inspect}"
        end
        raise "Unexpected child workflow ID: #{e.workflow_id}" unless e.workflow_id == 'child-id'
        raise "Unexpected child workflow type: #{e.workflow_type}" unless e.workflow_type == 'child-workflow'
      end
    end

    def test_replay_child_already_started
      replay_child_start_failure(
        :START_CHILD_WORKFLOW_EXECUTION_FAILED_CAUSE_WORKFLOW_ALREADY_EXISTS,
        'Temporalio::Error::WorkflowAlreadyStartedError'
      )
    end

    def test_replay_invalid_child_versioning_override
      replay_child_start_failure(
        :START_CHILD_WORKFLOW_EXECUTION_FAILED_CAUSE_INVALID_VERSIONING_OVERRIDE,
        'Temporalio::Error::InvalidVersioningOverrideError'
      )
    end

    def test_replay_child_namespace_not_found
      replay_child_start_failure(
        :START_CHILD_WORKFLOW_EXECUTION_FAILED_CAUSE_NAMESPACE_NOT_FOUND,
        'Temporalio::Error::NamespaceNotFoundError'
      )
    end

    def replay_child_start_failure(cause, expected_cause)
      converter = Temporalio::Converters::DataConverter.default
      # Synthetic history exercises start failures that do not require an invalid server deployment or namespace.
      # @type var event_attributes: Array[[Symbol, untyped]]
      event_attributes = [
        [:WORKFLOW_EXECUTION_STARTED, {
          workflow_type: { name: 'ChildStartFailureWorkflow' },
          workflow_id: 'parent-id',
          original_execution_run_id: SecureRandom.uuid,
          task_queue: { name: 'task-queue' },
          workflow_task_timeout: { seconds: 10 },
          input: converter.to_payloads([expected_cause])
        }],
        [:WORKFLOW_TASK_SCHEDULED, { task_queue: { name: 'task-queue' }, start_to_close_timeout: { seconds: 10 } }],
        [:WORKFLOW_TASK_STARTED, { scheduled_event_id: 2 }],
        [:WORKFLOW_TASK_COMPLETED, { scheduled_event_id: 2, started_event_id: 3 }],
        [:START_CHILD_WORKFLOW_EXECUTION_INITIATED, {
          namespace: 'default',
          workflow_id: 'child-id',
          workflow_type: { name: 'child-workflow' },
          task_queue: { name: 'task-queue' },
          workflow_task_completed_event_id: 4
        }],
        [:START_CHILD_WORKFLOW_EXECUTION_FAILED, {
          namespace: 'default',
          workflow_id: 'child-id',
          workflow_type: { name: 'child-workflow' },
          initiated_event_id: 5,
          workflow_task_completed_event_id: 4,
          cause: cause
        }],
        [:WORKFLOW_TASK_SCHEDULED, { task_queue: { name: 'task-queue' }, start_to_close_timeout: { seconds: 10 } }],
        [:WORKFLOW_TASK_STARTED, { scheduled_event_id: 7 }],
        [:WORKFLOW_TASK_COMPLETED, { scheduled_event_id: 7, started_event_id: 8 }],
        [:WORKFLOW_EXECUTION_COMPLETED, { workflow_task_completed_event_id: 9 }]
      ]
      events = event_attributes.each_with_index.map do |(event_type, attributes), index|
        Temporalio::Api::History::V1::HistoryEvent.new(
          event_id: index + 1,
          event_time: { seconds: 1_700_000_000 + index },
          event_type: :"EVENT_TYPE_#{event_type}",
          "#{event_type.to_s.downcase}_event_attributes": attributes
        )
      end
      history = Temporalio::WorkflowHistory.new(events)
      # A mismatched cause must contradict the recorded completion rather than merely fail a workflow task.
      result = Temporalio::Worker::WorkflowReplayer.new(
        workflows: [ChildStartFailureWorkflow],
        workflow_failure_exception_types: [StandardError]
      ).replay_workflow(history)
      assert_nil result.replay_failure
    end
  end
end
