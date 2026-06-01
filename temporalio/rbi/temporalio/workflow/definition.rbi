# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Workflow::Definition
  extend T::Sig

  sig { params(args: T.nilable(Object)).returns(T.nilable(Object)) }
  def execute(*args); end

  class << self
    extend T::Sig

    sig { params(workflow_name: T.any(String, Symbol)).void }
    def workflow_name(workflow_name); end

    sig { params(value: T::Boolean).void }
    def workflow_dynamic(value = T.unsafe(nil)); end

    sig { params(value: T::Boolean).void }
    def workflow_raw_args(value = T.unsafe(nil)); end

    sig { params(hints: Object).void }
    def workflow_arg_hint(*hints); end

    sig { params(hint: Object).void }
    def workflow_result_hint(hint); end

    sig { params(types: T.class_of(Exception)).void }
    def workflow_failure_exception_type(*types); end

    sig { params(attr_names: Symbol, description: T.nilable(String)).void }
    def workflow_query_attr_reader(*attr_names, description: T.unsafe(nil)); end

    sig { params(behavior: Integer).void }
    def workflow_versioning_behavior(behavior); end

    sig { params(value: T::Boolean).void }
    def workflow_init(value = T.unsafe(nil)); end

    sig do
      params(
        name: T.nilable(T.any(String, Symbol)),
        description: T.nilable(String),
        dynamic: T::Boolean,
        raw_args: T::Boolean,
        unfinished_policy: Integer,
        arg_hints: T.nilable(T.any(Object, T::Array[Object]))
      ).void
    end
    def workflow_signal(
      name: T.unsafe(nil),
      description: T.unsafe(nil),
      dynamic: T.unsafe(nil),
      raw_args: T.unsafe(nil),
      unfinished_policy: T.unsafe(nil),
      arg_hints: T.unsafe(nil)
    ); end

    sig do
      params(
        name: T.nilable(T.any(String, Symbol)),
        description: T.nilable(String),
        dynamic: T::Boolean,
        raw_args: T::Boolean,
        arg_hints: T.nilable(T.any(Object, T::Array[Object])),
        result_hint: T.nilable(Object)
      ).void
    end
    def workflow_query(
      name: T.unsafe(nil),
      description: T.unsafe(nil),
      dynamic: T.unsafe(nil),
      raw_args: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig do
      params(
        name: T.nilable(T.any(String, Symbol)),
        description: T.nilable(String),
        dynamic: T::Boolean,
        raw_args: T::Boolean,
        unfinished_policy: Integer,
        arg_hints: T.nilable(T.any(Object, T::Array[Object])),
        result_hint: T.nilable(Object)
      ).void
    end
    def workflow_update(
      name: T.unsafe(nil),
      description: T.unsafe(nil),
      dynamic: T.unsafe(nil),
      raw_args: T.unsafe(nil),
      unfinished_policy: T.unsafe(nil),
      arg_hints: T.unsafe(nil),
      result_hint: T.unsafe(nil)
    ); end

    sig { params(update_method: Symbol).void }
    def workflow_update_validator(update_method); end

    sig { void }
    def workflow_dynamic_options; end
  end
end

class Temporalio::Workflow::Definition::Info
  extend T::Sig

  sig { returns(T.class_of(Temporalio::Workflow::Definition)) }
  def workflow_class; end

  sig { returns(T.nilable(String)) }
  def override_name; end

  sig { returns(T::Boolean) }
  def dynamic; end

  sig { returns(T::Boolean) }
  def init; end

  sig { returns(T::Boolean) }
  def raw_args; end

  sig { returns(T::Array[T.class_of(Exception)]) }
  def failure_exception_types; end

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Signal]) }
  def signals; end

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Query]) }
  def queries; end

  sig { returns(T::Hash[T.nilable(String), Temporalio::Workflow::Definition::Update]) }
  def updates; end

  sig { returns(T.nilable(Integer)) }
  def versioning_behavior; end

  sig { returns(T.nilable(Symbol)) }
  def dynamic_options_method; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig { params(workflow_class: T.class_of(Temporalio::Workflow::Definition)).returns(Temporalio::Workflow::Definition::Info) }
  def self.from_class(workflow_class); end

  sig do
    params(
      workflow_class: T.class_of(Temporalio::Workflow::Definition),
      override_name: T.nilable(String),
      dynamic: T::Boolean,
      init: T::Boolean,
      raw_args: T::Boolean,
      failure_exception_types: T::Array[T.class_of(Exception)],
      signals: T::Hash[String, Temporalio::Workflow::Definition::Signal],
      queries: T::Hash[String, Temporalio::Workflow::Definition::Query],
      updates: T::Hash[String, Temporalio::Workflow::Definition::Update],
      versioning_behavior: T.nilable(Integer),
      dynamic_options_method: T.nilable(Symbol),
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(
    workflow_class:,
    override_name: T.unsafe(nil),
    dynamic: T.unsafe(nil),
    init: T.unsafe(nil),
    raw_args: T.unsafe(nil),
    failure_exception_types: T.unsafe(nil),
    signals: T.unsafe(nil),
    queries: T.unsafe(nil),
    updates: T.unsafe(nil),
    versioning_behavior: T.unsafe(nil),
    dynamic_options_method: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil)
  ); end

  sig { returns(T.nilable(String)) }
  def name; end
end

class Temporalio::Workflow::Definition::Signal
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def name; end

  sig { returns(T.any(Symbol, Proc)) }
  def to_invoke; end

  sig { returns(T.nilable(String)) }
  def description; end

  sig { returns(T::Boolean) }
  def raw_args; end

  sig { returns(Integer) }
  def unfinished_policy; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig do
    params(
      name: T.nilable(String),
      to_invoke: T.any(Symbol, Proc),
      description: T.nilable(String),
      raw_args: T::Boolean,
      unfinished_policy: Integer,
      arg_hints: T.nilable(T::Array[Object])
    ).void
  end
  def initialize(name:, to_invoke:, description: T.unsafe(nil), raw_args: T.unsafe(nil), unfinished_policy: T.unsafe(nil), arg_hints: T.unsafe(nil)); end
end

class Temporalio::Workflow::Definition::Query
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def name; end

  sig { returns(T.any(Symbol, Proc)) }
  def to_invoke; end

  sig { returns(T.nilable(String)) }
  def description; end

  sig { returns(T::Boolean) }
  def raw_args; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig do
    params(
      name: T.nilable(String),
      to_invoke: T.any(Symbol, Proc),
      description: T.nilable(String),
      raw_args: T::Boolean,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(name:, to_invoke:, description: T.unsafe(nil), raw_args: T.unsafe(nil), arg_hints: T.unsafe(nil), result_hint: T.unsafe(nil)); end
end

class Temporalio::Workflow::Definition::Update
  extend T::Sig

  sig { returns(T.nilable(String)) }
  def name; end

  sig { returns(T.any(Symbol, Proc)) }
  def to_invoke; end

  sig { returns(T.nilable(String)) }
  def description; end

  sig { returns(T::Boolean) }
  def raw_args; end

  sig { returns(Integer) }
  def unfinished_policy; end

  sig { returns(T.nilable(T.any(Symbol, Proc))) }
  def validator_to_invoke; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(Object)) }
  def result_hint; end

  sig do
    params(
      name: T.nilable(String),
      to_invoke: T.any(Symbol, Proc),
      description: T.nilable(String),
      raw_args: T::Boolean,
      unfinished_policy: Integer,
      validator_to_invoke: T.nilable(T.any(Symbol, Proc)),
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object)
    ).void
  end
  def initialize(
    name:,
    to_invoke:,
    description: T.unsafe(nil),
    raw_args: T.unsafe(nil),
    unfinished_policy: T.unsafe(nil),
    validator_to_invoke: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil)
  ); end
end
