# frozen_string_literal: true

module ProtobufSchedulerMutexWait
  def self.synchronize(mutex, &)
    mutex.synchronize(&)
  end
end
