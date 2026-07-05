# typed: true

module Temporalio::Internal::GoogleProtobuf
  extend T::Sig

  sig { params(locations: T.nilable(T::Array[Thread::Backtrace::Location])).returns(T::Boolean) }
  def self.in_call_stack?(locations); end
end
