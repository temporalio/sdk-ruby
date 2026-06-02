# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Workflow::Info < ::Struct
  extend T::Sig

  sig { returns(Integer) }
  def attempt; end

  sig { returns(T.nilable(String)) }
  def continued_run_id; end

  sig { returns(T.nilable(String)) }
  def cron_schedule; end

  sig { returns(T.nilable(Numeric)) }
  def execution_timeout; end

  sig { returns(String) }
  def first_execution_run_id; end

  sig { returns(T::Hash[String, Temporalio::Api::Common::V1::Payload]) }
  def headers; end

  sig { returns(T.nilable(Exception)) }
  def last_failure; end

  sig { returns(T.nilable(Object)) }
  def last_result; end

  sig { returns(T::Boolean) }
  def has_last_result?; end

  sig { returns(String) }
  def namespace; end

  sig { returns(T.nilable(Temporalio::Workflow::Info::ParentInfo)) }
  def parent; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(Temporalio::Workflow::Info::RootInfo)) }
  def root; end

  sig { returns(String) }
  def run_id; end

  sig { returns(T.nilable(Numeric)) }
  def run_timeout; end

  sig { returns(Time) }
  def start_time; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(Float) }
  def task_timeout; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(String) }
  def workflow_type; end

  sig { returns(T::Hash[Symbol, Object]) }
  def to_h; end
end

class Temporalio::Workflow::Info::ParentInfo < ::Struct
  extend T::Sig

  sig { returns(String) }
  def namespace; end

  sig { returns(String) }
  def run_id; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(T::Hash[Symbol, String]) }
  def to_h; end
end

class Temporalio::Workflow::Info::RootInfo < ::Struct
  extend T::Sig

  sig { returns(String) }
  def run_id; end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(T::Hash[Symbol, String]) }
  def to_h; end
end
