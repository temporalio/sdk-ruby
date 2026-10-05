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
  end
end
