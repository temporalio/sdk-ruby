require 'temporal/errors'

module Temporal
  # See https://docs.temporal.io/application-development/features/#workflow-retry-policy
  class RetryPolicy < Struct.new(
    :initial_interval,
    :backoff,
    :max_interval,
    :max_attempts,
    :non_retriable_errors,
    keyword_init: true,
  )
    Invalid = Class.new(Temporal::Error)

    def validate!
      # Retries disabled
      return if max_attempts == 1

      # Maximum attempts
      raise Invalid, 'Maximum attempts must be specified' unless max_attempts
      raise Invalid, 'Maximum attempts cannot be negative' if max_attempts.negative?

      # Initial interval
      raise Invalid, 'Initial interval must be specified' unless initial_interval
      raise Invalid, 'Initial interval cannot be negative' if initial_interval.negative?
      raise Invalid, 'Initial interval must be in whole seconds' unless initial_interval.is_a?(Integer)

      # Backoff coefficient
      raise Invalid, 'Backoff coefficient must be specified' unless backoff
      raise Invalid, 'Backoff coefficient cannot be less than 1' if backoff < 1

      # Maximum interval
      if max_interval
        raise Invalid, 'Maximum interval cannot be negative' if max_interval.negative?
        raise Invalid, 'Maximum interval cannot be less than initial interval' if max_interval < initial_interval
      end
    end
  end
end
