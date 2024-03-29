require 'temporal/api/common/v1/message_pb'
require 'temporalio/errors'

module Temporalio
  # Options for retrying workflows and activities.
  #
  # @see https://docs.temporal.io/application-development/features/#workflow-retry-policy
  class RetryPolicy
    class Invalid < Temporalio::Error; end

    # @return [Integer] Backoff interval for the first retry.
    attr_reader :initial_interval

    # @return [Float] Coefficient to multiply previous backoff interval by to get new interval.
    attr_reader :backoff

    # @return [Integer, nil] Maximum backoff interval between retries. Default 100x
    #   {#initial_interval}.
    attr_reader :max_interval

    # @return [Integer] Maximum number of attempts. If 0, the default, there is no maximum.
    attr_reader :max_attempts

    # @return [Array<String>] List of error types that are not retryable.
    attr_reader :non_retriable_errors

    def self.from_proto(proto)
      new(
        initial_interval: proto.initial_interval&.to_f&.round || 0,
        backoff: proto.backoff_coefficient&.to_f || 0.0,
        max_interval: proto.maximum_interval&.to_f&.round || 0,
        max_attempts: proto.maximum_attempts || 1,
        non_retriable_errors: proto.non_retryable_error_types || [],
      ).freeze
    end

    # @param initial_interval [Integer] Backoff interval (in seconds) for the first retry.
    # @param backoff [Float] Coefficient to multiply previous backoff interval by to get new
    #   interval.
    # @param max_interval [Integer] Maximum backoff interval between retries. Default 100x
    #   {#initial_interval}.
    # @param max_attempts [Integer] Maximum number of attempts. If 0, there is no maximum.
    # @param non_retriable_errors [Array<Class, String>] List of error types that are not retryable.
    def initialize(
      initial_interval: 1,
      backoff: 2.0,
      max_interval: nil,
      max_attempts: 0,
      non_retriable_errors: []
    )
      @initial_interval = initial_interval
      @backoff = backoff
      @max_interval = max_interval
      @max_attempts = max_attempts
      @non_retriable_errors = non_retriable_errors.map(&:to_s).compact
    end

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

    def to_proto
      Temporalio::Api::Common::V1::RetryPolicy.new(
        initial_interval: Google::Protobuf::Duration.new(seconds: initial_interval),
        backoff_coefficient: backoff,
        maximum_interval: max_interval ? Google::Protobuf::Duration.new(seconds: max_interval) : nil,
        maximum_attempts: max_attempts,
        non_retryable_error_types: non_retriable_errors,
      )
    end
  end
end
