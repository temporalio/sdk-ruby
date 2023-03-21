module Temporalio
  module Bridge
    class RetryConfig < Struct.new(
      :initial_interval_millis,
      :randomization_factor,
      :multiplier,
      :max_interval_millis,
      :max_retries,
      :max_elapsed_time_millis,
      keyword_init: true,
    ); end
  end
end
