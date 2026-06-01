# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::ScopedLogger < ::SimpleDelegator
  sig { params(obj: ::Logger).void }
  def initialize(obj); end

  sig { returns(T.nilable(Proc)) }
  def scoped_values_getter; end

  sig { params(value: T.nilable(Proc)).void }
  def scoped_values_getter=(value); end

  sig { returns(T::Boolean) }
  def disable_scoped_values; end

  sig { params(value: T::Boolean).void }
  def disable_scoped_values=(value); end

  sig { params(severity: T.nilable(Integer), message: T.nilable(Object), progname: T.nilable(Object)).void }
  def add(severity, message = nil, progname = nil); end

  sig { params(severity: T.nilable(Integer), message: T.nilable(Object), progname: T.nilable(Object)).void }
  def log(severity, message = nil, progname = nil); end

  sig { params(progname: T.nilable(Object), blk: T.nilable(T.proc.returns(Object))).void }
  def debug(progname = nil, &blk); end

  sig { params(progname: T.nilable(Object), blk: T.nilable(T.proc.returns(Object))).void }
  def info(progname = nil, &blk); end

  sig { params(progname: T.nilable(Object), blk: T.nilable(T.proc.returns(Object))).void }
  def warn(progname = nil, &blk); end

  sig { params(progname: T.nilable(Object), blk: T.nilable(T.proc.returns(Object))).void }
  def error(progname = nil, &blk); end

  sig { params(progname: T.nilable(Object), blk: T.nilable(T.proc.returns(Object))).void }
  def fatal(progname = nil, &blk); end

  sig { params(progname: T.nilable(Object), blk: T.nilable(T.proc.returns(Object))).void }
  def unknown(progname = nil, &blk); end
end

class Temporalio::ScopedLogger::LogMessage
  sig { params(message: Object, scoped_values: Object).void }
  def initialize(message, scoped_values); end

  sig { returns(Object) }
  def message; end

  sig { returns(Object) }
  def scoped_values; end

  sig { returns(String) }
  def inspect; end
end
