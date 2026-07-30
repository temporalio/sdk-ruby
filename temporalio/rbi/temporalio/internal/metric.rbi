# typed: true

class Temporalio::Internal::Metric < Temporalio::Metric
  extend T::Sig

  sig do
    params(
      metric_type: Symbol,
      name: String,
      description: T.nilable(String),
      unit: T.nilable(String),
      value_type: Symbol,
      bridge: Temporalio::Internal::Bridge::Metric,
      bridge_attrs: Temporalio::Internal::Bridge::Metric::Attributes
    ).void
  end
  def initialize(metric_type:, name:, description:, unit:, value_type:, bridge:, bridge_attrs:); end
end

class Temporalio::Internal::Metric::Meter < Temporalio::Metric::Meter
  extend T::Sig

  sig { params(runtime: Temporalio::Runtime).returns(T.nilable(Temporalio::Internal::Metric::Meter)) }
  def self.create_from_runtime(runtime); end

  sig do
    params(
      bridge: Temporalio::Internal::Bridge::Metric::Meter,
      bridge_attrs: Temporalio::Internal::Bridge::Metric::Attributes
    ).void
  end
  def initialize(bridge, bridge_attrs); end
end

class Temporalio::Internal::Metric::NullMeter < Temporalio::Metric::Meter
  extend T::Sig

  sig { returns(Temporalio::Internal::Metric::NullMeter) }
  def self.instance; end
end

class Temporalio::Internal::Metric::NullMetric < Temporalio::Metric
  extend T::Sig

  sig do
    params(
      metric_type: Symbol,
      name: String,
      description: T.nilable(String),
      unit: T.nilable(String),
      value_type: Symbol
    ).void
  end
  def initialize(metric_type:, name:, description:, unit:, value_type:); end
end
