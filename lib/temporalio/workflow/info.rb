module Temporalio
  class Workflow
    # Class containing information about a workflow's parent.
    class ParentInfo < Struct.new(
      :namespace,
      :run_id,
      :workflow_id,
      keyword_init: true,
    )
      # @!attribute [r] namespace
      #   @return [String] Namespace of the parent workflow.
      # @!attribute [r] run_id
      #   @return [String] Run ID of the parent workflow.
      # @!attribute [r] workflow_id
      #   @return [String] ID of the parent workflow.
    end

    # Class containing information about a workflow.
    class Info < Struct.new(
      :attempt,
      :continued_run_id,
      :cron_schedule,
      :execution_timeout,
      :headers,
      :namespace,
      :parent,
      :raw_memo,
      :retry_policy,
      :run_id,
      :run_timeout,
      :search_attributes,
      :start_time,
      :task_queue,
      :task_timeout,
      :workflow_id,
      :workflow_type,
      keyword_init: true,
    )
      # @!attribute [r] attempt
      #   @return [Integer] Attempt of executing the workflow.
      # @!attribute [r] continued_run_id
      #   @return [String] Run id of the previous workflow which continued-as-new or retired or cron
      #     executed into this workflow, if any.
      # @!attribute [r] cron_schedule
      #   @return [String] Cron schedule of the workflow.
      # @!attribute [r] execution_timeout
      #   @return [Float] Execution timeout of the workflow (in seconds).
      # @!attribute [r] headers
      #   @return [Hash<String, any>] Headers for the workflow.
      # @!attribute [r] namespace
      #   @return [String] Namespace of the workflow.
      # @!attribute [r] parent
      #   @return [Temporalio::Workflow::ParentInfo] Info of the parent workflow.
      # @!attribute [r] raw_memo
      #   @return [Hash<String, any>] Memo for the workflow.
      # @!attribute [r] retry_policy
      #   @return [Temporalio::RetryPolicy] RetryPolicy of the workflow.
      # @!attribute [r] run_id
      #   @return [String] Run ID of the workflow.
      # @!attribute [r] run_timeout
      #   @return [Float] Run timeout of the workflow (in seconds).
      # @!attribute [r] search_attributes
      #   @return [Hash<String, String>] Search attributes of the workflow.
      # @!attribute [r] start_time
      #   @return [Time] Start time of the workflow.
      # @!attribute [r] task_queue
      #   @return [String] Task queue of the workflow.
      # @!attribute [r] task_timeout
      #   @return [Float] Task timeout of the workflow (in seconds).
      # @!attribute [r] workflow_id
      #   @return [String] ID of the workflow.
      # @!attribute [r] workflow_type
      #   @return [String] Type of the workflow.
    end
  end
end
