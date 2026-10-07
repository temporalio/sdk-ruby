# typed: true

class Temporalio::Converters::StorageDriverWorkflowInfo < ::Data
  sig do
    params(
      namespace: String,
      id: T.nilable(String),
      run_id: T.nilable(String),
      type: T.nilable(String)
    ).void
  end
  def initialize(namespace:, id: T.unsafe(nil), run_id: T.unsafe(nil), type: T.unsafe(nil)); end

  sig { returns(String) }
  def namespace; end

  sig { returns(T.nilable(String)) }
  def id; end

  sig { returns(T.nilable(String)) }
  def run_id; end

  sig { returns(T.nilable(String)) }
  def type; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverWorkflowInfo) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Converters::StorageDriverWorkflowInfo) }
    def new(*args); end
  end
end
