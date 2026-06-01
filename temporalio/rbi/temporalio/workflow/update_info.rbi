# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Workflow::UpdateInfo < ::Struct
  extend T::Sig

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def name; end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end
end
