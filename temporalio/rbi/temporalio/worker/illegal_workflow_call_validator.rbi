# typed: true

class Temporalio::Worker::IllegalWorkflowCallValidator
  extend T::Sig

  sig { returns(T.nilable(Symbol)) }
  attr_reader :method_name

  sig { returns(T.proc.params(arg0: Temporalio::Worker::IllegalWorkflowCallValidator::CallInfo).void) }
  attr_reader :block

  sig { params(method_name: T.nilable(Symbol), block: T.proc.params(arg0: Temporalio::Worker::IllegalWorkflowCallValidator::CallInfo).void).void }
  def initialize(method_name: T.unsafe(nil), &block); end

  sig { returns(T::Array[Temporalio::Worker::IllegalWorkflowCallValidator]) }
  def self.default_time_validators; end

  sig { returns(Temporalio::Worker::IllegalWorkflowCallValidator) }
  def self.known_safe_mutex_validator; end
end

class Temporalio::Worker::IllegalWorkflowCallValidator::CallInfo < ::Data
  extend T::Sig

  sig { returns(String) }
  def class_name; end

  sig { returns(Symbol) }
  def method_name; end

  sig { returns(TracePoint) }
  def trace_point; end
end
