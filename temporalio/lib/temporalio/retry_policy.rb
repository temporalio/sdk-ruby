# frozen_string_literal: true

require 'temporalio/internal/proto_utils'

module Temporalio
  # Options for retrying workflows and activities.
  #
  # @!attribute initial_interval
  #   @return [Float] Backoff interval in seconds for the first retry. Default 1.0.
  # @!attribute backoff_coefficient
  #   @return [Float] Coefficient to multiply previous backoff interval by to get new interval. Default 2.0.
  # @!attribute max_interval
  #   @return [Float, nil] Maximum backoff interval in seconds between retries. Default 100x `initial_interval`.
  # @!attribute max_attempts
  #   @return [Integer] Maximum number of attempts. If `0`, the default, there is no maximum.
  # @!attribute non_retryable_error_types
  #   @return [Array<String>, nil] List of error types that are not retryable.
  RetryPolicy = Struct.new(
    :initial_interval,
    :backoff_coefficient,
    :max_interval,
    :max_attempts,
    :non_retryable_error_types,
    keyword_init: true
  ) do
    def initialize(*, **kwargs)
      kwargs[:initial_interval] = 1.0 unless kwargs.key?(:initial_interval)
      kwargs[:backoff_coefficient] = 2.0 unless kwargs.key?(:backoff_coefficient)
      kwargs[:max_attempts] = 0 unless kwargs.key?(:max_attempts)
      super
    end

    # @!visibility private
    def to_proto
      # @type self: RetryPolicy
      raise 'Initial interval cannot be negative' if initial_interval.negative?
      raise 'Backoff coefficient cannot be less than 1' if backoff_coefficient < 1
      raise 'Max interval cannot be negative' if max_interval&.negative?
      raise 'Max interval cannot be less than initial interval' if max_interval && max_interval < initial_interval
      raise 'Max attempts cannot be negative' if max_attempts.negative?

      Api::Common::V1::RetryPolicy.new(
        initial_interval: Internal::ProtoUtils.seconds_to_duration(initial_interval),
        backoff_coefficient:,
        maximum_interval: Internal::ProtoUtils.seconds_to_duration(max_interval),
        maximum_attempts: max_attempts,
        non_retryable_error_types:
      )
    end
  end
end
