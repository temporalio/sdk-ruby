# frozen_string_literal: true

module Temporalio
  class Runtime
    # Metric buffer for use with a runtime to capture metrics. Only one metric buffer can be associated with a runtime
    # and {retrieve_updates} cannot be called before the runtime is created. Once runtime created, users should
    # regularly call {retrieve_updates} to drain the buffer.
    #
    # @note WARNING: It is important that the buffer size is set to a high number and that {retrieve_updates} is called
    #   regularly to drain the buffer. If the buffer is full, metric updates will be dropped and an error will be
    #   logged.
    class MetricBuffer
      # Enumerates for the duration format.
      module DurationFormat
        # Durations are millisecond integers.
        MILLISECONDS = :milliseconds

        # Durations are second floats.
        SECONDS = :seconds
      end

      Update = Data.define(:metric, :value, :attributes)

      # Metric buffer update.
      #
      # @note WARNING: The constructor of this class should not be invoked by users and may change in incompatible ways
      #   in the future.
      #
      # @!attribute metric
      #   @return [Metric] Metric for this update. For performance reasons, this is created lazily on first use and is
      #     the same object each time an update on this metric exists.
      # @!attribute value
      #   @return [Integer, Float] Metric value for this update.
      # @!attribute attributes
      #   @return [Hash{String => String, Integer, Float, Boolean}] Attributes for this value as a frozen hash.
      #     For performance reasons this is sometimes the same hash if the attribute set is reused at a metric level.
      class Update # rubocop:disable Lint/EmptyClass
        # DEV NOTE: This class is instantiated inside Rust, be careful changing it.
      end

      Metric = Data.define(:name, :description, :unit, :kind)

      # Metric definition present on an update.
      #
      # @!attribute name
      #   @return [String] Name of the metric.
      # @!attribute description
      #   @return [String, nil] Description of the metric if any.
      # @!attribute unit
      #   @return [String, nil] Unit of the metric if any.
      # @!attribute kind
      #   @return [:counter, :histogram, :gauge] Kind of the metric.
      class Metric # rubocop:disable Lint/EmptyClass
        # DEV NOTE: This class is instantiated inside Rust, be careful changing it.
      end

      # Create a metric buffer with the given size.
      #
      # @note WARNING: It is important that the buffer size is set to a high number and is drained regularly. See
      #   {MetricBuffer} warning.
      #
      # @param buffer_size [Integer] Maximum size of the buffer before metrics will be dropped.
      # @param duration_format [DurationFormat] How durations are represented.
      def initialize(buffer_size, duration_format: DurationFormat::MILLISECONDS)
        @buffer_size = buffer_size
        @duration_format = duration_format
        @runtime = nil
      end

      # Drain the buffer and return all metric updates.
      #
      # @note WARNING: It is important that this is called regularly. See {MetricBuffer} warning.
      #
      # @return [Array<Update>] Updates since last time this was called.
      def retrieve_updates
        raise 'Attempting to retrieve updates before runtime created' unless @runtime

        @runtime._core_runtime.retrieve_buffered_metrics(@duration_format == DurationFormat::SECONDS)
      end

      # @!visibility private
      def _buffer_size
        @buffer_size
      end

      # @!visibility private
      def _set_runtime(runtime)
        raise 'Metric buffer already attached to a runtime' if @runtime

        @runtime = runtime
      end
    end
  end
end
