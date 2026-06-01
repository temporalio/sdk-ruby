# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Cancellation
  sig { params(parents: Temporalio::Cancellation).void }
  def initialize(*parents); end

  sig { returns(T::Boolean) }
  def canceled?; end

  sig { returns(T.nilable(String)) }
  def canceled_reason; end

  sig { returns(T::Boolean) }
  def pending_canceled?; end

  sig { returns(T.nilable(String)) }
  def pending_canceled_reason; end

  sig { params(err: Exception).void }
  def check!(err = T.unsafe(nil)); end

  sig { returns([Temporalio::Cancellation, Proc]) }
  def to_ary; end

  sig { void }
  def wait; end

  sig do
    type_parameters(:T)
      .params(blk: T.proc.returns(T.type_parameter(:T)))
      .returns(T.type_parameter(:T))
  end
  def shield(&blk); end

  sig { params(block: T.proc.void).returns(Object) }
  def add_cancel_callback(&block); end

  sig { params(key: Object).void }
  def remove_cancel_callback(key); end
end
