module Temporalio
  class Connection
    class RetryConfig
      # Initial backoff interval.
      # @default 100
      attr_reader :initial_interval_millis

      # Randomization jitter to add.
      # @default 0.2
      attr_reader :randomization_factor

      # Backoff multiplier.
      # @default 1.5
      attr_reader :multiplier

      # Maximum backoff interval.
      # @default 5000
      attr_reader :max_interval_millis

      # Maximum total time (optional).
      attr_reader :max_elapsed_time_millis

      # Maximum number of retries.
      # @default 10
      attr_reader :max_retries

      def initialize(
        initial_interval_millis: nil,
        randomization_factor: nil,
        multiplier: nil,
        max_interval_millis: nil,
        max_elapsed_time_millis: nil,
        max_retries: nil
      )
        @initial_interval_millis = initial_interval_millis || 100
        @randomization_factor = randomization_factor || 0.2
        @multiplier = multiplier || 1.5
        @max_interval_millis = max_interval_millis || 5_000
        @max_elapsed_time_millis = max_elapsed_time_millis
        @max_retries = max_retries || 10
      end
    end
  end
end
