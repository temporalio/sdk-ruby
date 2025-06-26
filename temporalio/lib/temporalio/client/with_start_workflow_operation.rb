# frozen_string_literal: true

require 'temporalio/common_enums'

module Temporalio
  class Client
    # Start operation used by {Client.start_update_with_start_workflow}, {Client.execute_update_with_start_workflow},
    # and {Client.signal_with_start_workflow}.
    class WithStartWorkflowOperation
      Options = Data.define(
        :workflow,
        :args,
        :id,
        :task_queue,
        :static_summary,
        :static_details,
        :execution_timeout,
        :run_timeout,
        :task_timeout,
        :id_reuse_policy,
        :id_conflict_policy,
        :retry_policy,
        :cron_schedule,
        :memo,
        :search_attributes,
        :start_delay,
        :arg_hints,
        :result_hint,
        :headers
      )

      # Options the operation was created with.
      class Options; end # rubocop:disable Lint/EmptyClass

      # @return [Options] Options the operation was created with.
      attr_accessor :options

      # Create a with-start workflow operation. These are mostly the same options as {Client.start_workflow}, see that
      # documentation for more details.
      #
      # Note, for {Client.start_update_with_start_workflow} and {Client.execute_update_with_start_workflow},
      # `id_conflict_policy` is required.
      def initialize(
        workflow,
        *args,
        id:,
        task_queue:,
        static_summary: nil,
        static_details: nil,
        execution_timeout: nil,
        run_timeout: nil,
        task_timeout: nil,
        id_reuse_policy: WorkflowIDReusePolicy::ALLOW_DUPLICATE,
        id_conflict_policy: WorkflowIDConflictPolicy::UNSPECIFIED,
        retry_policy: nil,
        cron_schedule: nil,
        memo: nil,
        search_attributes: nil,
        start_delay: nil,
        arg_hints: nil,
        result_hint: nil,
        headers: {}
      )
        workflow, defn_arg_hints, defn_result_hint =
          Workflow::Definition._workflow_type_and_hints_from_workflow_parameter(workflow)
        @options = Options.new(
          workflow:,
          args:,
          id:,
          task_queue:,
          static_summary:,
          static_details:,
          execution_timeout:,
          run_timeout:,
          task_timeout:,
          id_reuse_policy:,
          id_conflict_policy:,
          retry_policy:,
          cron_schedule:,
          memo:,
          search_attributes:,
          start_delay:,
          arg_hints: arg_hints || defn_arg_hints,
          result_hint: result_hint || defn_result_hint,
          headers:
        )
        @workflow_handle_mutex = Mutex.new
        @workflow_handle_cond_var = ConditionVariable.new
      end

      # Get the workflow handle, possibly waiting until set, or raise an error if the workflow start was unsuccessful.
      #
      # @param wait [Boolean] True to wait until it is set, false to return immediately.
      #
      # @return [WorkflowHandle, nil] The workflow handle when available or `nil` if `wait` is false and it is not set
      #   yet.
      # @raise [Error] Any error that occurred during the call before the workflow start returned.
      def workflow_handle(wait: true)
        @workflow_handle_mutex.synchronize do
          @workflow_handle_cond_var.wait(@workflow_handle_mutex) unless @workflow_handle || !wait
          raise @workflow_handle if @workflow_handle.is_a?(Exception)

          @workflow_handle
        end
      end

      # @!visibility private
      def _set_workflow_handle(value)
        @workflow_handle_mutex.synchronize do
          @workflow_handle ||= value
          @workflow_handle_cond_var.broadcast
        end
      end

      # @!visibility private
      def _mark_used
        raise 'Start operation already used' if @in_use

        @in_use = true
      end
    end
  end
end
