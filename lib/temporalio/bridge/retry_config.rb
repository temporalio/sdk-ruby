module Temporalio
  module Bridge
    class RetryConfig
      attr_reader :initial_interval_millis, :randomization_factor, :multiplier,
                  :max_interval_millis, :max_elapsed_time_millis, :max_retries

      def initialize(
        initial_interval_millis:,
        randomization_factor:,
        multiplier:,
        max_interval_millis:,
        max_retries:,
        max_elapsed_time_millis:
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
