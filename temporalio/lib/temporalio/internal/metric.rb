# frozen_string_literal: true

require 'temporalio/internal/bridge'
require 'temporalio/metric'

module Temporalio
  module Internal
    class Metric < Temporalio::Metric
      attr_reader :metric_type, :name, :description, :unit, :value_type

      def initialize(metric_type:, name:, description:, unit:, value_type:, bridge:, bridge_attrs:) # rubocop:disable Lint/MissingSuper
        @metric_type = metric_type
        @name = name
        @description = description
        @unit = unit
        @value_type = value_type
        @bridge = bridge
        @bridge_attrs = bridge_attrs
      end

      def record(value, additional_attributes: nil)
        bridge_attrs = @bridge_attrs
        bridge_attrs = @bridge_attrs.with_additional(additional_attributes) if additional_attributes
        @bridge.record_value(value, bridge_attrs)
      end

      def with_additional_attributes(additional_attributes)
        Metric.new(
          metric_type:,
          name:,
          description:,
          unit:,
          value_type:,
          bridge: @bridge,
          bridge_attrs: @bridge_attrs.with_additional(additional_attributes)
        )
      end

      class Meter < Temporalio::Metric::Meter
        def self.create_from_runtime(runtime)
          bridge = Bridge::Metric::Meter.new(runtime._core_runtime)
          return nil unless bridge

          Meter.new(bridge, bridge.default_attributes)
        end

        def initialize(bridge, bridge_attrs) # rubocop:disable Lint/MissingSuper
          @bridge = bridge
          @bridge_attrs = bridge_attrs
        end

        def create_metric(
          metric_type,
          name,
          description: nil,
          unit: nil,
          value_type: :integer
        )
          Metric.new(
            metric_type:,
            name:,
            description:,
            unit:,
            value_type:,
            bridge: Bridge::Metric.new(@bridge, metric_type, name, description, unit, value_type),
            bridge_attrs: @bridge_attrs
          )
        end

        def with_additional_attributes(additional_attributes)
          Meter.new(@bridge, @bridge_attrs.with_additional(additional_attributes))
        end
      end

      class NullMeter < Temporalio::Metric::Meter
        include Singleton

        def initialize # rubocop:disable Style/RedundantInitialize,Lint/MissingSuper
        end

        def create_metric(
          metric_type,
          name,
          description: nil,
          unit: nil,
          value_type: :integer
        )
          NullMetric.new(
            metric_type:,
            name:,
            description:,
            unit:,
            value_type:
          )
        end

        def with_additional_attributes(_additional_attributes)
          self
        end
      end

      class NullMetric < Temporalio::Metric
        attr_reader :metric_type, :name, :description, :unit, :value_type

        def initialize(metric_type:, name:, description:, unit:, value_type:) # rubocop:disable Lint/MissingSuper
          @metric_type = metric_type
          @name = name
          @description = description
          @unit = unit
          @value_type = value_type
        end

        def record(value, additional_attributes: nil); end

        def with_additional_attributes(_additional_attributes)
          self
        end
      end
    end
  end
end
