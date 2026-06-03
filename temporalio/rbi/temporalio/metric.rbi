# typed: true

class Temporalio::Metric
  sig do
    params(
      value: Numeric,
      additional_attributes: T.nilable(T::Hash[T.any(String, Symbol), T.any(String, Integer, Float, T::Boolean)])
    ).void
  end
  def record(value, additional_attributes: nil); end

  sig do
    params(
      additional_attributes: T::Hash[T.any(String, Symbol), T.any(String, Integer, Float, T::Boolean)]
    ).returns(Temporalio::Metric)
  end
  def with_additional_attributes(additional_attributes); end

  sig { returns(Symbol) }
  def metric_type; end

  sig { returns(String) }
  def name; end

  sig { returns(T.nilable(String)) }
  def description; end

  sig { returns(T.nilable(String)) }
  def unit; end

  sig { returns(Symbol) }
  def value_type; end
end

class Temporalio::Metric::Meter
  sig { returns(Temporalio::Metric::Meter) }
  def self.null; end

  sig do
    params(
      metric_type: Symbol,
      name: String,
      description: T.nilable(String),
      unit: T.nilable(String),
      value_type: Symbol
    ).returns(Temporalio::Metric)
  end
  def create_metric(metric_type, name, description: nil, unit: nil, value_type: :integer); end

  sig do
    params(
      additional_attributes: T::Hash[T.any(String, Symbol), T.any(String, Integer, Float, T::Boolean)]
    ).returns(Temporalio::Metric::Meter)
  end
  def with_additional_attributes(additional_attributes); end
end
