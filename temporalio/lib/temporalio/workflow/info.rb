# frozen_string_literal: true

module Temporalio
  module Workflow
    Info = Struct.new(
      :attempt,
      :continued_run_id,
      :cron_schedule,
      :execution_timeout,
      :headers,
      :last_failure,
      :last_result,
      :namespace,
      :parent,
      :retry_policy,
      :root,
      :run_id,
      :run_timeout,
      :start_time,
      :task_queue,
      :task_timeout,
      :workflow_id,
      :workflow_type,
      keyword_init: true
    )

    # Information about the running workflow. This is immutable for the life of the workflow run.
    #
    # @!attribute attempt
    #   @return [Integer] Current workflow attempt.
    # @!attribute continued_run_id
    #   @return [String, nil] Run ID if this was continued.
    # @!attribute cron_schedule
    #   @return [String, nil] Cron schedule if applicable.
    # @!attribute execution_timeout
    #   @return [Float, nil] Execution timeout for the workflow.
    # @!attribute headers
    #   @return [Hash<String, Api::Common::V1::Payload>] Headers.
    # @!attribute last_failure
    #   @return [Exception, nil] Failure if this workflow run is a continuation of a failure.
    # @!attribute last_result
    #   @return [Object, nil] Successful result if this workflow is a continuation of a success.
    # @!attribute namespace
    #   @return [String] Namespace for the workflow.
    # @!attribute parent
    #   @return [ParentInfo, nil] Parent information for the workflow if this is a child.
    # @!attribute retry_policy
    #   @return [RetryPolicy, nil] Retry policy for the workflow.
    # @!attribute root
    #   @return [RootInfo, nil] Root information for the workflow. This is nil in pre-1.27.0 server versions or if there
    #     is no root (i.e. the root is itself).
    # @!attribute run_id
    #   @return [String] Run ID for the workflow.
    # @!attribute run_timeout
    #   @return [Float, nil] Run timeout for the workflow.
    # @!attribute start_time
    #   @return [Time] Time when the workflow started.
    # @!attribute task_queue
    #   @return [String] Task queue for the workflow.
    # @!attribute task_timeout
    #   @return [Float] Task timeout for the workflow.
    # @!attribute workflow_id
    #   @return [String] ID for the workflow.
    # @!attribute workflow_type
    #   @return [String] Workflow type name.
    #
    # @note WARNING: This class may have required parameters added to its constructor. Users should not instantiate this
    #   class or it may break in incompatible ways.
    class Info
      # Information about a parent of a workflow.
      #
      # @!attribute namespace
      #   @return [String] Namespace for the parent.
      # @!attribute run_id
      #   @return [String] Run ID for the parent.
      # @!attribute workflow_id
      #   @return [String] Workflow ID for the parent.
      #
      # @note WARNING: This class may have required parameters added to its constructor. Users should not instantiate
      #   this class or it may break in incompatible ways.
      ParentInfo = Struct.new(
        :namespace,
        :run_id,
        :workflow_id,
        keyword_init: true
      )

      # Information about a root of a workflow.
      #
      # @!attribute run_id
      #   @return [String] Run ID for the root.
      # @!attribute workflow_id
      #   @return [String] Workflow ID for the root.
      #
      # @note WARNING: This class may have required parameters added to its constructor. Users should not instantiate
      #   this class or it may break in incompatible ways.
      RootInfo = Struct.new(
        :run_id,
        :workflow_id,
        keyword_init: true
      )
    end
  end
end
