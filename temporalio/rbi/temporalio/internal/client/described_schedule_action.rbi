# typed: true

class Temporalio::Internal::Client::DescribedScheduleAction
  extend T::Sig

  sig { returns(Temporalio::Api::Workflow::V1::NewWorkflowExecutionInfo) }
  def raw_info; end

  sig do
    params(
      action: Temporalio::Client::Schedule::Action::StartWorkflow,
      raw_info: Temporalio::Api::Workflow::V1::NewWorkflowExecutionInfo
    ).void
  end
  def initialize(action, raw_info); end

  sig { params(name: Symbol, value: T.nilable(Object)).returns(T::Boolean) }
  def unchanged?(name, value); end

  sig { params(name: Symbol, value: T.nilable(String)).returns(T::Boolean) }
  def unchanged_text?(name, value); end
end
