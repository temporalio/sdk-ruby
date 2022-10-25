require 'temporal/workflow/execution_status'
require 'google/protobuf/well_known_types'

module Temporal
  class Workflow
    class ExecutionInfo < Struct.new(
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
      keyword_init: true,
    )
      def self.from_raw(response, converter)
        raw_info = response.workflow_execution_info
        raise 'unexpected' unless raw_info

        new(
          raw: response,
          workflow: raw_info.type&.name,
          id: raw_info.execution&.workflow_id,
          run_id: raw_info.execution&.run_id,
          task_queue: raw_info.task_queue,
          status: Workflow::ExecutionStatus.from_raw(raw_info.status),
          parent_id: raw_info.parent_execution&.workflow_id,
          parent_run_id: raw_info.parent_execution&.run_id,
          start_time: raw_info.start_time&.to_time,
          close_time: raw_info.close_time&.to_time,
          execution_time: raw_info.execution_time&.to_time,
          history_length: raw_info.history_length,
          memo: converter.from_payload_map(raw_info.memo&.fields),
          search_attributes: converter.from_payload_map(raw_info.search_attributes&.indexed_fields),
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
