# frozen_string_literal: true

require 'temporalio/internal/metric'

module Temporalio
  # Metric that can be recorded from a metric meter. This is obtained via {Meter.create_metric}. The metric meter is
  # obtained via workflow environment, activity context, or from the {Runtime} if in neither of those. This class is
  # effectively abstract and will fail if `initialize` is attempted.
  class Metric
    # @!visibility private
    def initialize
      raise NotImplementedError, 'Metric is abstract, implementations override initialize'
    end

    # Record a value for the metric. For counters, this adds to any existing. For histograms, this records into proper
    # buckets. For gauges, this sets the value. The value type must match the expectation.
    #
    # @param value [Numeric] Value to record. For counters and duration-based histograms, this value cannot be negative.
    # @param additional_attributes [Hash{String, Symbol => String, Integer, Float, Boolean}, nil] Additional attributes
    #   on this specific record. For better performance for attribute reuse, users are encouraged to use
    #   {with_additional_attributes} to make a copy of this metric with those attributes.
    def record(value, additional_attributes: nil)
      raise NotImplementedError
    end

    # Create a copy of this metric but with the given additional attributes. This is more performant than providing
    # attributes on each {record} call.
    #
    # @param additional_attributes [Hash{String, Symbol => String, Integer, Float, Boolean}] Attributes to set on the
    #   resulting metric.
    # @return [Metric] Copy of this metric with the additional attributes.
    def with_additional_attributes(additional_attributes)
      raise NotImplementedError
    end

    # @return [:counter, :histogram, :gauge] Metric type.
    def metric_type
      raise NotImplementedError
    end

    # @return [String] Metric name.
    def name
      raise NotImplementedError
    end

    # @return [String, nil] Metric description.
    def description
      raise NotImplementedError
    end

    # @return [String, nil] Metric unit.
    def unit
      raise NotImplementedError
    end

    # @return [:integer, :float, :duration] Metric value type.
    def value_type
      raise NotImplementedError
    end

    # Meter for creating metrics to record values on. This is obtained via workflow environment, activity context, or
    # from the {Runtime} if in neither of those. This class is effectively abstract and will fail if `initialize` is
    # attempted.
    class Meter
      # @return [Meter] A no-op instance of {Meter}.
      def self.null
        Internal::Metric::NullMeter.instance
      end

      # @!visibility private
      def initialize
        raise NotImplementedError, 'Meter is abstract, implementations override initialize'
      end

      # Create a new metric. Only certain metric types are accepted and only value types can work with certain metric
      # types.
      #
      # @param metric_type [:counter, :histogram, :gauge] Metric type. Counters can only have `:integer` value types,
      #   histograms can have `:integer`, `:float`, or :duration` value types, and gauges can have `:integer` or
      #   `:float` value types.
      # @param name [String] Metric name.
      # @param description [String, nil] Metric description.
      # @param unit [String, nil] Metric unit.
      # @param value_type [:integer, :float, :duration] Metric value type. `:integer` works for all metric types,
      #   `:float` works for `:histogram` and `:gauge` metric types, and `:duration` only works for `:histogram` metric
      #   types.
      # @return [Metric] Created metric.
      def create_metric(
        metric_type,
        name,
        description: nil,
        unit: nil,
        value_type: :integer
      )
        raise NotImplementedError
      end

      # Create a copy of this meter but with the given additional attributes. This is more performant than providing
      # attributes on each {record} call.
      #
      # @param additional_attributes [Hash{String, Symbol => String, Integer, Float, Boolean}] Attributes to set on the
      #   resulting meter.
      # @return [Meter] Copy of this meter with the additional attributes.
      def with_additional_attributes(additional_attributes)
        raise NotImplementedError
      end
    end
  end
end
