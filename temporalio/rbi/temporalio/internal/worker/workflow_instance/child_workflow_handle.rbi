# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::ChildWorkflowHandle < Temporalio::Workflow::ChildWorkflowHandle
  extend T::Sig

  sig do
    params(
      id: String,
      first_execution_run_id: String,
      instance: Temporalio::Internal::Worker::WorkflowInstance,
      cancellation: Temporalio::Cancellation,
      cancel_callback_key: Object,
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(id:, first_execution_run_id:, instance:, cancellation:, cancel_callback_key:, result_hint:); end

  sig { params(resolution: Temporalio::Internal::Bridge::Api::ChildWorkflow::ChildWorkflowResult).void }
  def _resolve(resolution); end
end
