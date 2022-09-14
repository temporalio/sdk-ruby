require 'temporal/errors'

module Temporal
  # See https://docs.temporal.io/application-development/features/#workflow-retry-policy
  class RetryPolicy < Struct.new(
    :initial_interval,
    :backoff,
    :max_interval,
    :max_attempts,
    :non_retriable_errors,
    keyword_init: true
  )
    Invalid = Class.new(Temporal::Error)

    def validate!
      # Retries disabled
      return if max_attempts == 1

      # Maximum attempts
      unless max_attempts
        raise Invalid, 'Maximum attempts must be specified'
      end

      if max_attempts.negative?
        raise Invalid, 'Maximum attempts cannot be negative'
      end

      # Initial interval
      unless initial_interval
        raise Invalid, 'Initial interval must be specified'
      end

      if initial_interval.negative?
        raise Invalid, 'Initial interval cannot be negative'
      end

      unless initial_interval.is_a?(Integer)
        raise Invalid, 'Initial interval must be in whole seconds'
      end

      # Backoff coefficient
      unless backoff
        raise Invalid, 'Backoff coefficient must be specified'
      end

      if backoff < 1
        raise Invalid, 'Backoff coefficient cannot be less than 1'
      end

      # Maximum interval
      if max_interval
        if max_interval.negative?
          raise Invalid, 'Maximum interval cannot be negative'
        end

        if max_interval < initial_interval
          raise Invalid, 'Maximum interval cannot be less than initial interval'
        end
      end
    end
  end
end
