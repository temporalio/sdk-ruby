require 'temporal/workflow/execution_status'
require 'google/protobuf/well_known_types'

module Temporal
  class Workflow
    EXECUTION_INFO_ATTRIBUTES = [
      :raw,
      :workflow,
      :id,
      :run_id,
      :task_queue,
      :status,
      :parent_id,
      :parent_run_id,
      :start_time,
      :close_time,
      :execution_time,
      :history_length,
      :memo,
      :search_attributes,
    ].freeze

    class ExecutionInfo < Struct.new(*EXECUTION_INFO_ATTRIBUTES, keyword_init: true)
      def self.from_raw(response)
        self.new(
          raw: response,
          workflow: response.workflow_execution_info.type.name,
          id: response.workflow_execution_info.execution.workflow_id,
          run_id: response.workflow_execution_info.execution.run_id,
          task_queue: response.workflow_execution_info.task_queue,
          status: Workflow::ExecutionStatus.from_raw(response.workflow_execution_info.status),
          parent_id: response.workflow_execution_info.parent_execution&.workflow_id,
          parent_run_id: response.workflow_execution_info.parent_execution&.run_id,
          start_time: response.workflow_execution_info.start_time&.to_time,
          close_time: response.workflow_execution_info.close_time&.to_time,
          execution_time: response.workflow_execution_info.execution_time&.to_time,
          history_length: response.workflow_execution_info.history_length,

          # TODO: Decode using converters
          memo: response.workflow_execution_info.memo,
          # TODO: Decode using converters
          search_attributes: response.workflow_execution_info.search_attributes,
        ).freeze
      end

      # Helper methods for checking execution status
      Workflow::ExecutionStatus::STATUSES.each do |status|
        define_method("#{status.downcase}?") do
          self.status == status
        end
      end
    end
  end
end
