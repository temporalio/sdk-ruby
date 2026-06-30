# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::NexusOperationHandle < Temporalio::Workflow::NexusOperationHandle
  extend T::Sig

  sig do
    params(
      operation_token: T.nilable(String),
      instance: Temporalio::Internal::Worker::WorkflowInstance,
      cancellation: Temporalio::Cancellation,
      cancel_callback_key: Object,
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(operation_token:, instance:, cancellation:, cancel_callback_key:, result_hint:); end

  sig { params(resolution: Object).void }
  def _resolve(resolution); end
end
