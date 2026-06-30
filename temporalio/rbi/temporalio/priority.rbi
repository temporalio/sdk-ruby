# typed: true

class Temporalio::Priority < ::Data
  sig do
    params(
      priority_key: T.nilable(Integer),
      fairness_key: T.nilable(String),
      fairness_weight: T.nilable(Float)
    ).void
  end
  def initialize(priority_key: nil, fairness_key: nil, fairness_weight: nil); end

  sig { returns(Temporalio::Priority) }
  def self.default; end

  sig { returns(T.nilable(Integer)) }
  def priority_key; end

  sig { returns(T.nilable(String)) }
  def fairness_key; end

  sig { returns(T.nilable(Numeric)) }
  def fairness_weight; end

  sig { returns(T::Boolean) }
  def empty?; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Priority) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end

    sig { params(args: T.untyped).returns(Temporalio::Priority) }
    def new(*args); end
  end
end
