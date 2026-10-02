# typed: true

class Temporalio::Converters::StorageDriverClaim
  extend T::Sig

  sig { returns(T::Hash[String, String]) }
  attr_reader :claim_data

  sig { params(claim_data: T::Hash[String, String]).void }
  def initialize(claim_data); end

  sig { params(other: T.untyped).returns(T::Boolean) }
  def ==(other); end

  sig { params(other: T.untyped).returns(T::Boolean) }
  def eql?(other); end

  sig { returns(Integer) }
  def hash; end
end
