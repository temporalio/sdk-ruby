# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Activity::Definition
  sig { params(args: Object).returns(Object) }
  def execute(*args); end

  class << self
    protected

    sig { params(name: T.any(String, Symbol)).void }
    def activity_name(name); end

    sig { params(executor_name: Symbol).void }
    def activity_executor(executor_name); end

    sig { params(cancel_raise: T::Boolean).void }
    def activity_cancel_raise(cancel_raise); end

    sig { params(value: T::Boolean).void }
    def activity_dynamic(value = true); end

    sig { params(value: T::Boolean).void }
    def activity_raw_args(value = true); end

    sig { params(hints: Object).void }
    def activity_arg_hint(*hints); end

    sig { params(hint: T.nilable(Object)).void }
    def activity_result_hint(hint); end
  end
end

class Temporalio::Activity::Definition::Info
  sig do
    params(
      name: T.nilable(T.any(String, Symbol)),
      instance: T.nilable(T.any(Object, Proc)),
      executor: Symbol,
      cancel_raise: T::Boolean,
      raw_args: T::Boolean,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      block: T.nilable(T.proc.params(arg0: Object).returns(Object))
    ).void
  end
  def initialize(name:, instance: nil, executor: :default, cancel_raise: true, raw_args: false, arg_hints: nil, result_hint: nil, &block); end

  sig { params(activity: T.any(Temporalio::Activity::Definition, T.class_of(Temporalio::Activity::Definition), Temporalio::Activity::Definition::Info)).returns(Temporalio::Activity::Definition::Info) }
  def self.from_activity(activity); end

  sig { returns(T.nilable(T.any(String, Symbol))) }
  def name; end

  sig { returns(T.nilable(T.any(Object, Proc))) }
  def instance; end

  sig { returns(Proc) }
  def proc; end

  sig { returns(Symbol) }
  def executor; end

  sig { returns(T::Boolean) }
  def cancel_raise; end

  sig { returns(T::Boolean) }
  def raw_args; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end
end
