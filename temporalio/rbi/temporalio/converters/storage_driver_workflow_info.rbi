# typed: true

class Temporalio::Converters::StorageDriverWorkflowInfo
  extend T::Sig

  sig { returns(String) }
  attr_reader :namespace

  sig { returns(T.nilable(String)) }
  attr_reader :id

  sig { returns(T.nilable(String)) }
  attr_reader :run_id

  sig { returns(T.nilable(String)) }
  attr_reader :type

  sig do
    params(
      namespace: String,
      id: T.nilable(String),
      run_id: T.nilable(String),
      type: T.nilable(String)
    ).void
  end
  def initialize(namespace:, id: T.unsafe(nil), run_id: T.unsafe(nil), type: T.unsafe(nil)); end
end
