# typed: true

class Temporalio::Client::WorkflowExecution
  sig { params(raw_info: Temporalio::Api::Workflow::V1::WorkflowExecutionInfo, data_converter: Temporalio::Converters::DataConverter).void }
  def initialize(raw_info, data_converter); end

  sig { returns(Temporalio::Api::Workflow::V1::WorkflowExecutionInfo) }
  attr_reader :raw_info

  sig { returns(T.nilable(Time)) }
  def close_time; end

  sig { returns(T.nilable(Time)) }
  def execution_time; end

  sig { returns(Integer) }
  def history_length; end

  sig { returns(String) }
  def id; end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(String)) }
  def parent_id; end

  sig { returns(T.nilable(String)) }
  def parent_run_id; end

  sig { returns(String) }
  def run_id; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(Time) }
  def start_time; end

  sig { returns(Integer) }
  def status; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(String) }
  def workflow_type; end
end

class Temporalio::Client::WorkflowExecution::Description < ::Temporalio::Client::WorkflowExecution
  sig { params(raw_description: Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse, data_converter: Temporalio::Converters::DataConverter).void }
  def initialize(raw_description, data_converter); end

  sig { returns(Temporalio::Api::WorkflowService::V1::DescribeWorkflowExecutionResponse) }
  attr_reader :raw_description

  sig { returns(T.nilable(String)) }
  def static_summary; end

  sig { returns(T.nilable(String)) }
  def static_details; end
end
