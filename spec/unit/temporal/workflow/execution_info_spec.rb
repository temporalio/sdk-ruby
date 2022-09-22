require 'securerandom'
require 'temporal/api/workflowservice/v1/request_response_pb'
require 'temporal/converter'
require 'temporal/workflow/execution_info'
require 'temporal/workflow/execution_status'

describe Temporal::Workflow::ExecutionInfo do
  subject { described_class.from_raw(proto, converter) }

  let(:converter) { Temporal::Converter.new }
  let(:id) { SecureRandom.uuid }
  let(:run_id) { SecureRandom.uuid }
  let(:time_now) { Time.now }
  let(:payload) do
    Temporal::Api::Common::V1::Payload.new(
      metadata: { 'encoding' => 'json/plain' },
      data: '"test"',
    )
  end
  let(:proto) do
    Temporal::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse.new(
      workflow_execution_info: {
        execution: { workflow_id: id, run_id: run_id },
        type: { name: 'TestWorkflow' },
        task_queue: 'test-queue',
        start_time: { nanos: time_now.nsec, seconds: time_now.to_i },
        close_time: { nanos: time_now.nsec, seconds: time_now.to_i },
        status: :WORKFLOW_EXECUTION_STATUS_COMPLETED,
        history_length: 4,
        parent_execution: { workflow_id: 'parent-id', run_id: 'parent-run-id' },
        execution_time: { nanos: time_now.nsec, seconds: time_now.to_i },
        memo: { fields: { 'memo' => payload } },
        search_attributes: { indexed_fields: { 'attrs' => payload } },
      },
    )
  end

  describe '.from_raw' do
    it 'generates itself from proto' do
      expect(subject.raw).to eq(proto)
      expect(subject.workflow).to eq('TestWorkflow')
      expect(subject.id).to eq(id)
      expect(subject.run_id).to eq(run_id)
      expect(subject.task_queue).to eq('test-queue')
      expect(subject.status).to eq(Temporal::Workflow::ExecutionStatus::COMPLETED)
      expect(subject.parent_id).to eq('parent-id')
      expect(subject.parent_run_id).to eq('parent-run-id')
      expect(subject.start_time).to eq(time_now)
      expect(subject.close_time).to eq(time_now)
      expect(subject.execution_time).to eq(time_now)
      expect(subject.history_length).to eq(4)
      expect(subject.memo).to eq({ 'memo' => 'test' })
      expect(subject.search_attributes).to eq({ 'attrs' => 'test' })
    end
  end
end
