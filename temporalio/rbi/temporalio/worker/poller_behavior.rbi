# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Worker::PollerBehavior; end

class Temporalio::Worker::PollerBehavior::SimpleMaximum < ::Temporalio::Worker::PollerBehavior
  extend T::Sig

  sig { returns(Integer) }
  attr_reader :maximum

  sig { params(maximum: Integer).void }
  def initialize(maximum); end
end

class Temporalio::Worker::PollerBehavior::Autoscaling < ::Temporalio::Worker::PollerBehavior
  extend T::Sig

  sig { returns(Integer) }
  attr_reader :minimum

  sig { returns(Integer) }
  attr_reader :maximum

  sig { returns(Integer) }
  attr_reader :initial

  sig { params(minimum: Integer, maximum: Integer, initial: Integer).void }
  def initialize(minimum: T.unsafe(nil), maximum: T.unsafe(nil), initial: T.unsafe(nil)); end
end
