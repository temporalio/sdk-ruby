# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Converters::RawValue
  extend T::Sig

  sig { returns(Temporalio::Api::Common::V1::Payload) }
  def payload; end

  sig { params(payload: Temporalio::Api::Common::V1::Payload).void }
  def initialize(payload); end
end
