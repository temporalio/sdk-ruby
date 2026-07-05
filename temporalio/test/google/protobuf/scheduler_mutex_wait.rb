# frozen_string_literal: true

# This util is here specifically to ensure that "google/protobuf" is in the call stack.
module ProtobufSchedulerMutexWait
  def self.synchronize(mutex, &)
    mutex.synchronize(&)
  end
end
