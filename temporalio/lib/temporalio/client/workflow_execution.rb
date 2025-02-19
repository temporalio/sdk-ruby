# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/workflow_execution_status'
require 'temporalio/internal/proto_utils'
require 'temporalio/search_attributes'

module Temporalio
  class Client
    # Info for a single workflow execution run.
    class WorkflowExecution
      # @return [Api::Workflow::V1::WorkflowExecutionInfo] Underlying protobuf info.
      attr_reader :raw_info

      # @!visibility private
      def initialize(raw_info, data_converter)
        @raw_info = raw_info
        @memo = Internal::ProtoUtils::LazyMemo.new(raw_info.memo, data_converter)
        @search_attributes = Internal::ProtoUtils::LazySearchAttributes.new(raw_info.search_attributes)
      end

      # @return [Time, nil] When the workflow was closed if closed.
      def close_time
        Internal::ProtoUtils.timestamp_to_time(@raw_info.close_time)
      end

      # @return [Time, nil] When this workflow run started or should start.
      def execution_time
        Internal::ProtoUtils.timestamp_to_time(@raw_info.execution_time)
      end

      # @return [Integer] Number of events in the history.
      def history_length
        @raw_info.history_length
      end

      # @return [String] ID for the workflow.
      def id
        @raw_info.execution.workflow_id
      end

      # @return [Hash<String, Object>, nil] Memo for the workflow.
      def memo
        @memo.get
      end

      # @return [String, nil] ID for the parent workflow if this was started as a child.
      def parent_id
        @raw_info.parent_execution&.workflow_id
      end

      # @return [String, nil] Run ID for the parent workflow if this was started as a child.
      def parent_run_id
        @raw_info.parent_execution&.run_id
      end

      # @return [String] Run ID for this workflow run.
      def run_id
        @raw_info.execution.run_id
      end

      # @return [SearchAttributes, nil] Current set of search attributes if any.
      def search_attributes
        @search_attributes.get
      end

      # @return [Time] When the workflow was created.
      def start_time
        Internal::ProtoUtils.timestamp_to_time(@raw_info.start_time) || raise # Never nil
      end

      # @return [WorkflowExecutionStatus] Status for the workflow.
      def status
        Internal::ProtoUtils.enum_to_int(Api::Enums::V1::WorkflowExecutionStatus, @raw_info.status)
      end

      # @return [String] Task queue for the workflow.
      def task_queue
        @raw_info.task_queue
      end

      # @return [String] Type name for the workflow.
      def workflow_type
        @raw_info.type.name
      end

      # Description for a single workflow execution run.
      class Description < WorkflowExecution
        # @return [Api::WorkflowService::V1::DescribeWorkflowExecutionResponse] Underlying protobuf description.
        attr_reader :raw_description

        # @!visibility private
        def initialize(raw_description, data_converter)
          super(raw_description.workflow_execution_info, data_converter)
          @raw_description = raw_description
          @data_converter = data_converter
        end

        # @return [String, nil] Static summary configured on the workflow. This is currently experimental.
        def static_summary
          user_metadata.first
        end

        # @return [String, nil] Static details configured on the workflow. This is currently experimental.
        def static_details
          user_metadata.last
        end

        private

        def user_metadata
          @user_metadata ||= Internal::ProtoUtils.from_user_metadata(
            @raw_description.execution_config&.user_metadata, @data_converter
          )
        end
      end
    end
  end
end
