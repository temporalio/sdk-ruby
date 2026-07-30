# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::ExternalWorkflowHandle < Temporalio::Workflow::ExternalWorkflowHandle
  extend T::Sig

  sig do
    params(
      id: String,
      run_id: T.nilable(String),
      instance: Object
    ).void
  end
  def initialize(id:, run_id:, instance:); end
end
