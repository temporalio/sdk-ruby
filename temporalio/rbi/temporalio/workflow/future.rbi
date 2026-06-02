# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Workflow::Future
  extend T::Sig
  extend T::Generic

  Elem = type_member

  sig { returns(T.nilable(Elem)) }
  def result; end

  sig { returns(T.nilable(Exception)) }
  def failure; end

  sig { params(block: T.nilable(T.proc.returns(Elem))).void }
  def initialize(&); end

  sig { returns(T::Boolean) }
  def done?; end

  sig { returns(T::Boolean) }
  def result?; end

  sig { params(result: Elem).void }
  def result=(result); end

  sig { returns(T::Boolean) }
  def failure?; end

  sig { params(failure: Exception).void }
  def failure=(failure); end

  sig { returns(Elem) }
  def wait; end

  sig { returns(T.nilable(Elem)) }
  def wait_no_raise; end

  class << self
    extend T::Sig

    sig { params(futures: Temporalio::Workflow::Future[T.untyped]).returns(Temporalio::Workflow::Future[NilClass]) }
    def all_of(*futures); end

    sig do
      type_parameters(:T)
        .params(futures: Temporalio::Workflow::Future[T.type_parameter(:T)])
        .returns(Temporalio::Workflow::Future[T.type_parameter(:T)])
    end
    def any_of(*futures); end

    sig do
      type_parameters(:T)
        .params(futures: Temporalio::Workflow::Future[T.type_parameter(:T)])
        .returns(Temporalio::Workflow::Future[Temporalio::Workflow::Future[T.type_parameter(:T)]])
    end
    def try_any_of(*futures); end

    sig { params(futures: Temporalio::Workflow::Future[T.untyped]).returns(Temporalio::Workflow::Future[NilClass]) }
    def try_all_of(*futures); end
  end
end
