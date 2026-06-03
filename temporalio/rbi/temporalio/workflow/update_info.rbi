# typed: true

class Temporalio::Workflow::UpdateInfo < ::Struct
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def name; end

  sig { returns(T::Hash[Symbol, String]) }
  def to_h; end
end
