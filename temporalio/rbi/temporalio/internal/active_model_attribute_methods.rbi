# typed: true

module Temporalio::Internal::ActiveModelAttributeMethods
  extend T::Sig

  sig { params(locations: T.nilable(T::Array[Thread::Backtrace::Location])).returns(T::Boolean) }
  def self.in_concurrent_map_call_stack?(locations); end

  sig { params(locations: T.nilable(T::Array[Thread::Backtrace::Location])).returns(T::Boolean) }
  def self.in_cache_computation_call_stack?(locations); end
end
