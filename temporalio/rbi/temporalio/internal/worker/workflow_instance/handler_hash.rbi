# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::HandlerHash < Hash
  extend T::Sig

  sig do
    params(
      initial_frozen_hash: T::Hash[T.nilable(String), Object],
      definition_class: T.any(
        T.class_of(Temporalio::Workflow::Definition::Signal),
        T.class_of(Temporalio::Workflow::Definition::Query),
        T.class_of(Temporalio::Workflow::Definition::Update)
      ),
      on_new_definition: T.nilable(T.proc.params(arg0: Object).void)
    ).void
  end
  def initialize(initial_frozen_hash, definition_class, &on_new_definition); end

  sig { params(name: T.nilable(String), definition: Object).returns(Object) }
  def []=(name, definition); end

  sig { params(name: T.nilable(String), definition: Object).returns(Object) }
  def store(name, definition); end
end
