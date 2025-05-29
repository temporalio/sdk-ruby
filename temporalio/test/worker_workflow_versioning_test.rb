# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/common_enums'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/worker/deployment_options'
require 'temporalio/worker_deployment_version'
require 'temporalio/workflow'
require 'temporalio/workflow/definition'
require 'test'
require 'timeout'

class WorkerWorkflowVersioningTest < Test
  class DeploymentVersioningWorkflowV1AutoUpgrade < Temporalio::Workflow::Definition
    workflow_name :DeploymentVersioningWorkflow
    workflow_versioning_behavior Temporalio::VersioningBehavior::AUTO_UPGRADE
    workflow_query_attr_reader :state

    def initialize
      @finish = false
      @state = 'v1'
    end

    def execute
      Temporalio::Workflow.wait_condition { @finish }
      'version-v1'
    end

    workflow_signal
    def do_finish
      @finish = true
    end
  end

  class DeploymentVersioningWorkflowV2Pinned < Temporalio::Workflow::Definition
    workflow_name :DeploymentVersioningWorkflow
    workflow_versioning_behavior Temporalio::VersioningBehavior::PINNED
    workflow_query_attr_reader :state

    def initialize
      @finish = false
      @state = 'v2'
    end

    def execute
      Temporalio::Workflow.wait_condition { @finish }
      depver = Temporalio::Workflow.current_deployment_version
      raise 'No deployment version' unless depver
      raise 'Wrong build id' unless depver.build_id == '2.0'

      # Just ensuring the rust object was converted properly and this method still works
      Temporalio::Workflow.logger.debug("Dep string: #{depver.to_canonical_string}")
      'version-v2'
    end

    workflow_signal
    def do_finish
      @finish = true
    end
  end

  class DeploymentVersioningWorkflowV3AutoUpgrade < Temporalio::Workflow::Definition
    workflow_name :DeploymentVersioningWorkflow
    workflow_versioning_behavior Temporalio::VersioningBehavior::AUTO_UPGRADE
    workflow_query_attr_reader :state

    def initialize
      @finish = false
      @state = 'v3'
    end

    def execute
      Temporalio::Workflow.wait_condition { @finish }
      'version-v3'
    end

    workflow_signal
    def do_finish
      @finish = true
    end
  end

  def test_worker_deployment_version
    deployment_name = "deployment-#{SecureRandom.uuid}"
    worker_v1 = Temporalio::WorkerDeploymentVersion.new(
      deployment_name: deployment_name, build_id: '1.0'
    )
    worker_v2 = Temporalio::WorkerDeploymentVersion.new(
      deployment_name: deployment_name, build_id: '2.0'
    )
    worker_v3 = Temporalio::WorkerDeploymentVersion.new(
      deployment_name: deployment_name, build_id: '3.0'
    )

    task_queue = "tq-#{SecureRandom.uuid}"

    # Create and start all workers
    workers = []
    begin
      # Worker 1
      worker1 = Temporalio::Worker.new(
        client: env.client,
        task_queue: task_queue,
        workflows: [DeploymentVersioningWorkflowV1AutoUpgrade],
        deployment_options: Temporalio::Worker::DeploymentOptions.new(
          version: worker_v1,
          use_worker_versioning: true
        )
      )
      workers << worker1

      # Worker 2
      worker2 = Temporalio::Worker.new(
        client: env.client,
        task_queue: task_queue,
        workflows: [DeploymentVersioningWorkflowV2Pinned],
        deployment_options: Temporalio::Worker::DeploymentOptions.new(
          version: worker_v2,
          use_worker_versioning: true
        )
      )
      workers << worker2

      # Worker 3
      worker3 = Temporalio::Worker.new(
        client: env.client,
        task_queue: task_queue,
        workflows: [DeploymentVersioningWorkflowV3AutoUpgrade],
        deployment_options: Temporalio::Worker::DeploymentOptions.new(
          version: worker_v3,
          use_worker_versioning: true
        )
      )
      workers << worker3

      Temporalio::Worker.run_all(*workers) do
        # Wait for worker v1 to be visible and set as current
        describe_resp = wait_until_worker_deployment_visible(env.client, worker_v1)
        set_current_deployment_version(env.client, describe_resp.conflict_token, worker_v1)

        # Start workflow 1 which will use the 1.0 worker on auto-upgrade
        handle1 = env.client.start_workflow(
          DeploymentVersioningWorkflowV1AutoUpgrade,
          id: 'basic-versioning-v1',
          task_queue: task_queue
        )
        assert_equal 'v1', handle1.query(DeploymentVersioningWorkflowV1AutoUpgrade.state)

        # Set v2 as current deployment
        describe_resp2 = wait_until_worker_deployment_visible(env.client, worker_v2)
        set_current_deployment_version(env.client, describe_resp2.conflict_token, worker_v2)

        # Start workflow 2 which will use the 2.0 worker on pinned
        handle2 = env.client.start_workflow(
          DeploymentVersioningWorkflowV2Pinned,
          id: 'basic-versioning-v2',
          task_queue: task_queue
        )
        assert_equal 'v2', handle2.query(DeploymentVersioningWorkflowV2Pinned.state)

        # Set v3 as current deployment
        describe_resp3 = wait_until_worker_deployment_visible(env.client, worker_v3)
        set_current_deployment_version(env.client, describe_resp3.conflict_token, worker_v3)

        # Start workflow 3 which will use the 3.0 worker on auto-upgrade
        handle3 = env.client.start_workflow(
          DeploymentVersioningWorkflowV3AutoUpgrade,
          id: 'basic-versioning-v3',
          task_queue: task_queue
        )
        assert_equal 'v3', handle3.query(DeploymentVersioningWorkflowV3AutoUpgrade.state)

        # Signal all workflows to finish
        handle1.signal(DeploymentVersioningWorkflowV1AutoUpgrade.do_finish)
        handle2.signal(DeploymentVersioningWorkflowV2Pinned.do_finish)
        handle3.signal(DeploymentVersioningWorkflowV3AutoUpgrade.do_finish)

        # Get results
        res1 = handle1.result
        res2 = handle2.result
        res3 = handle3.result

        # Check results
        assert_equal 'version-v3', res1
        assert_equal 'version-v2', res2
        assert_equal 'version-v3', res3
      end
    end
  end

  def test_worker_deployment_ramp
    deployment_name = "deployment-ramping-#{SecureRandom.uuid}"
    worker_v1 = Temporalio::WorkerDeploymentVersion.new(
      deployment_name: deployment_name, build_id: '1.0'
    )
    worker_v2 = Temporalio::WorkerDeploymentVersion.new(
      deployment_name: deployment_name, build_id: '2.0'
    )

    # Create workers
    workers = []
    begin
      # Worker 1
      worker1 = Temporalio::Worker.new(
        client: env.client,
        task_queue: "tq-#{SecureRandom.uuid}",
        workflows: [DeploymentVersioningWorkflowV1AutoUpgrade],
        deployment_options: Temporalio::Worker::DeploymentOptions.new(
          version: worker_v1,
          use_worker_versioning: true
        )
      )
      workers << worker1

      # Worker 2
      worker2 = Temporalio::Worker.new(
        client: env.client,
        task_queue: worker1.task_queue,
        workflows: [DeploymentVersioningWorkflowV2Pinned],
        deployment_options: Temporalio::Worker::DeploymentOptions.new(
          version: worker_v2,
          use_worker_versioning: true
        )
      )
      workers << worker2

      Temporalio::Worker.run_all(*workers) do
        # Wait for worker deployments to be visible
        wait_until_worker_deployment_visible(env.client, worker_v1)
        describe_resp = wait_until_worker_deployment_visible(env.client, worker_v2)

        # Set current version to v1 and ramp v2 to 100%
        conflict_token = set_current_deployment_version(
          env.client,
          describe_resp.conflict_token,
          worker_v1
        ).conflict_token
        conflict_token = set_ramping_version(
          env.client,
          conflict_token,
          worker_v2,
          100.0
        ).conflict_token

        # Run workflows and verify they run on v2
        3.times do |i|
          handle = env.client.start_workflow(
            DeploymentVersioningWorkflowV2Pinned,
            id: "versioning-ramp-100-#{i}-#{SecureRandom.uuid}",
            task_queue: worker1.task_queue
          )
          handle.signal(DeploymentVersioningWorkflowV2Pinned.do_finish)
          assert_equal 'version-v2', handle.result
        end

        # Set ramp to 0, expecting workflows to run on v1
        conflict_token = set_ramping_version(
          env.client,
          conflict_token,
          worker_v2,
          0.0
        ).conflict_token

        3.times do |i|
          handle = env.client.start_workflow(
            DeploymentVersioningWorkflowV1AutoUpgrade,
            id: "versioning-ramp-0-#{i}-#{SecureRandom.uuid}",
            task_queue: worker1.task_queue
          )
          handle.signal(DeploymentVersioningWorkflowV1AutoUpgrade.do_finish)
          assert_equal 'version-v1', handle.result
        end

        # Set ramp to 50 and eventually verify workflows run on both versions
        set_ramping_version(env.client, conflict_token, worker_v2, 50.0)
        seen_results = Set.new

        # Keep running workflows until we've seen both versions
        assert_eventually do
          handle = env.client.start_workflow(
            DeploymentVersioningWorkflowV1AutoUpgrade,
            id: "versioning-ramp-50-#{SecureRandom.uuid}",
            task_queue: worker1.task_queue
          )
          handle.signal(DeploymentVersioningWorkflowV1AutoUpgrade.do_finish)
          res = handle.result
          seen_results.add(res)
          seen_results.include?('version-v1') && seen_results.include?('version-v2')
        end
      end
    end
  end

  class DynamicWorkflowVersioningOnDefn < Temporalio::Workflow::Definition
    workflow_dynamic
    workflow_versioning_behavior Temporalio::VersioningBehavior::PINNED

    def execute(*_raw_args)
      'dynamic'
    end
  end

  class DynamicWorkflowVersioningOnConfigMethod < Temporalio::Workflow::Definition
    workflow_dynamic
    workflow_versioning_behavior Temporalio::VersioningBehavior::PINNED

    workflow_dynamic_options
    def dynamic_options
      Temporalio::Workflow::DefinitionOptions.new(
        versioning_behavior: Temporalio::VersioningBehavior::AUTO_UPGRADE
      )
    end

    def execute(*_raw_args)
      'dynamic'
    end
  end

  def test_worker_deployment_dynamic_workflow_with_pinned
    _test_worker_deployment_dynamic_workflow(
      DynamicWorkflowVersioningOnDefn,
      Temporalio::Api::Enums::V1::VersioningBehavior::VERSIONING_BEHAVIOR_PINNED
    )
  end

  def test_worker_deployment_dynamic_workflow_with_auto_upgrade
    _test_worker_deployment_dynamic_workflow(
      DynamicWorkflowVersioningOnConfigMethod,
      Temporalio::Api::Enums::V1::VersioningBehavior::VERSIONING_BEHAVIOR_AUTO_UPGRADE
    )
  end

  def _test_worker_deployment_dynamic_workflow(workflow_class, expected_versioning_behavior)
    deployment_name = "deployment-dynamic-#{SecureRandom.uuid}"
    worker_v1 = Temporalio::WorkerDeploymentVersion.new(
      deployment_name: deployment_name, build_id: '1.0'
    )

    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [workflow_class],
      deployment_options: Temporalio::Worker::DeploymentOptions.new(
        version: worker_v1,
        use_worker_versioning: true
      )
    )

    worker.run do
      describe_resp = wait_until_worker_deployment_visible(env.client, worker_v1)
      set_current_deployment_version(env.client, describe_resp.conflict_token, worker_v1)

      handle = env.client.start_workflow(
        'cooldynamicworkflow',
        id: "dynamic-workflow-versioning-#{SecureRandom.uuid}",
        task_queue: worker.task_queue
      )
      result = handle.result
      assert_equal 'dynamic', result

      events = handle.fetch_history.events
      has_expected_behavior = events.any? do |event|
        event.workflow_task_completed_event_attributes &&
          event.workflow_task_completed_event_attributes.versioning_behavior ==
            Temporalio::Api::Enums::V1::VersioningBehavior.lookup(expected_versioning_behavior.to_i)
      end
      assert has_expected_behavior, "Expected versioning behavior #{expected_versioning_behavior} not found in history"
    end
  end

  class NoVersioningAnnotationWorkflow < Temporalio::Workflow::Definition
    def execute
      'whee'
    end
  end

  class NoVersioningAnnotationDynamicWorkflow < Temporalio::Workflow::Definition
    workflow_dynamic

    def execute(*_raw_args)
      'whee'
    end
  end

  def test_workflows_must_have_versioning_behavior_when_feature_turned_on
    error = assert_raises(ArgumentError) do
      Temporalio::Worker.new(
        client: env.client,
        task_queue: 'whatever',
        workflows: [NoVersioningAnnotationWorkflow],
        deployment_options: Temporalio::Worker::DeploymentOptions.new(
          version: Temporalio::WorkerDeploymentVersion.new(
            deployment_name: 'whatever', build_id: '1.0'
          ),
          use_worker_versioning: true
        )
      )
    end
    assert_includes error.message, 'must specify a versioning behavior'

    error = assert_raises(ArgumentError) do
      Temporalio::Worker.new(
        client: env.client,
        task_queue: 'whatever',
        workflows: [NoVersioningAnnotationDynamicWorkflow],
        deployment_options: Temporalio::Worker::DeploymentOptions.new(
          version: Temporalio::WorkerDeploymentVersion.new(
            deployment_name: 'whatever', build_id: '1.0'
          ),
          use_worker_versioning: true
        )
      )
    end
    assert_includes error.message, 'must specify a versioning behavior'
  end

  def test_workflows_can_use_default_versioning_behavior
    deployment_name = "deployment-default-versioning-#{SecureRandom.uuid}"
    worker_v1 = Temporalio::WorkerDeploymentVersion.new(
      deployment_name: deployment_name, build_id: '1.0'
    )

    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [NoVersioningAnnotationWorkflow],
      deployment_options: Temporalio::Worker::DeploymentOptions.new(
        version: worker_v1,
        use_worker_versioning: true,
        default_versioning_behavior: Temporalio::VersioningBehavior::PINNED
      )
    )

    worker.run do
      describe_resp = wait_until_worker_deployment_visible(env.client, worker_v1)
      set_current_deployment_version(env.client, describe_resp.conflict_token, worker_v1)

      handle = env.client.start_workflow(
        NoVersioningAnnotationWorkflow,
        id: "default-versioning-behavior-#{SecureRandom.uuid}",
        task_queue: worker.task_queue
      )
      handle.result

      events = handle.fetch_history.events
      has_expected_behavior = events.any? do |event|
        event.workflow_task_completed_event_attributes &&
          event.workflow_task_completed_event_attributes.versioning_behavior ==
            Temporalio::Api::Enums::V1::VersioningBehavior.lookup(
              Temporalio::Api::Enums::V1::VersioningBehavior::VERSIONING_BEHAVIOR_PINNED.to_i
            )
      end
      assert has_expected_behavior, 'Expected versioning behavior PINNED not found in history'
    end
  end

  def test_default_build_id
    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: "tq-#{SecureRandom.uuid}",
      workflows: [NoVersioningAnnotationWorkflow]
    )
    build_id = Temporalio::Worker.default_build_id

    worker.run do
      handle = env.client.start_workflow(
        NoVersioningAnnotationWorkflow,
        id: "default-build-id-#{SecureRandom.uuid}",
        task_queue: worker.task_queue
      )
      handle.result

      events = handle.fetch_history.events
      has_expected_behavior = events.any? do |event|
        event.workflow_task_completed_event_attributes &&
          event.workflow_task_completed_event_attributes.worker_version.build_id == build_id
      end
      assert has_expected_behavior, 'Expected versioning behavior PINNED not found in history'
    end
  end

  def wait_until_worker_deployment_visible(client, version)
    assert_eventually do
      res = client.workflow_service.describe_worker_deployment(
        Temporalio::Api::WorkflowService::V1::DescribeWorkerDeploymentRequest.new(
          namespace: client.namespace,
          deployment_name: version.deployment_name
        )
      )
      assert(res.worker_deployment_info.version_summaries.any? do |vs|
        vs.version == version.to_canonical_string
      end)
      res
    rescue Temporalio::Error::RPCError
      # Expected
      assert false
    end
  end

  def set_current_deployment_version(client, conflict_token, version)
    client.workflow_service.set_worker_deployment_current_version(
      Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentCurrentVersionRequest.new(
        namespace: client.namespace,
        deployment_name: version.deployment_name,
        version: version.to_canonical_string,
        conflict_token: conflict_token
      )
    )
  end

  def set_ramping_version(client, conflict_token, version, percentage)
    client.workflow_service.set_worker_deployment_ramping_version(
      Temporalio::Api::WorkflowService::V1::SetWorkerDeploymentRampingVersionRequest.new(
        namespace: client.namespace,
        deployment_name: version.deployment_name,
        version: version.to_canonical_string,
        conflict_token: conflict_token,
        percentage: percentage
      )
    )
  end

  def test_workflows_can_use_versioning_override
    # Test that versioning override works when starting a workflow
    deployment_name = "deployment-versioning-override-#{SecureRandom.uuid}"
    worker_v1 = Temporalio::WorkerDeploymentVersion.new(
      deployment_name: deployment_name,
      build_id: '1.0'
    )
    task_queue = "tq-#{SecureRandom.uuid}"

    require 'temporalio/versioning_override'

    worker = Temporalio::Worker.new(
      client: env.client,
      task_queue: task_queue,
      workflows: [DeploymentVersioningWorkflowV1AutoUpgrade],
      deployment_options: Temporalio::Worker::DeploymentOptions.new(
        version: worker_v1, use_worker_versioning: true
      )
    )

    worker.run do
      # Wait for deployment to be visible
      describe_resp = wait_until_worker_deployment_visible(env.client, worker_v1)
      # Set current deployment version
      set_current_deployment_version(env.client, describe_resp.conflict_token, worker_v1)

      # Start workflow with pinned versioning override
      handle = env.client.start_workflow(
        DeploymentVersioningWorkflowV1AutoUpgrade,
        id: "override-versioning-#{SecureRandom.uuid}",
        task_queue: task_queue,
        versioning_override: Temporalio::VersioningOverride::Pinned.new(worker_v1)
      )

      # Send signal to finish
      handle.signal(:do_finish)
      # Wait for workflow to complete
      handle.result

      # Verify in the history that versioning override was applied
      history = handle.fetch_history
      execution_started_event = history.events.find { |evt| evt.event_type == :EVENT_TYPE_WORKFLOW_EXECUTION_STARTED }
      # Check if the versioning override is present in the workflow execution started event
      assert(execution_started_event.workflow_execution_started_event_attributes.versioning_override)
    end
  end
end
