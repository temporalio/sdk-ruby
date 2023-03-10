module Temporalio
  module Bridge
    class RetryConfig
      # Initial backoff interval.
      attr_reader :initial_interval_millis

      # Randomization jitter to add.
      attr_reader :randomization_factor

      # Backoff multiplier.
      attr_reader :multiplier

      # Maximum backoff interval.
      attr_reader :max_interval_millis

      # Maximum total time.
      attr_reader :max_elapsed_time_millis

      # Maximum number of retries.
      attr_reader :max_retries

      def initialize(
        initial_interval_millis:,
        randomization_factor:,
        multiplier:,
        max_interval_millis:,
        max_retries:
        :max_elapsed_time_millis => nil,
      )
        @initial_interval_millis = initial_interval_millis
        @randomization_factor = randomization_factor
        @multiplier = multiplier
        @max_interval_millis = max_interval_millis
        @max_retries = max_retries
        @max_elapsed_time_millis = max_elapsed_time_millis
      end
    end
  end
end
