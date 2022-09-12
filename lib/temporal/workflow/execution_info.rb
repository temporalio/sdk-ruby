module Temporal
  class Workflow
    EXECUTION_INFO_ATTRIBUTES = %i[workflow workflow_id run_id status start_time close_time].freeze

    class ExecutionInfo < Struct.new(*EXECUTION_INFO_ATTRIBUTES, keyword_init: true)
      def self.from_raw(response)
        self.new(
          workflow: response.workflow_execution_info.type.name,
          workflow_id: response.workflow_execution_info.execution.workflow_id,
          run_id: response.workflow_execution_info.execution.run_id,
          status: response.workflow_execution_info.status,
          start_time: response.workflow_execution_info.start_time&.seconds,
          close_time: response.workflow_execution_info.close_time&.seconds,
        ).freeze
      end
    end
  end
end
