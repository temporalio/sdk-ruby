# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::InboundImplementation < Temporalio::Worker::Interceptor::Workflow::Inbound
  extend T::Sig

  sig { params(instance: Temporalio::Internal::Worker::WorkflowInstance).void }
  def initialize(instance); end

  sig do
    params(
      name: String,
      input: T.any(
        Temporalio::Worker::Interceptor::Workflow::HandleSignalInput,
        Temporalio::Worker::Interceptor::Workflow::HandleQueryInput,
        Temporalio::Worker::Interceptor::Workflow::HandleUpdateInput
      ),
      to_invoke: T.nilable(T.any(Symbol, Proc))
    ).returns(T.nilable(Object))
  end
  def invoke_handler(name, input, to_invoke: T.unsafe(nil)); end
end
