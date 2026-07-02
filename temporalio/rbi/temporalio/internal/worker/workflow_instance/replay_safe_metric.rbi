# typed: true

class Temporalio::Internal::Worker::WorkflowInstance::ReplaySafeMetric < Temporalio::Metric
  extend T::Sig

  sig { params(obj: Temporalio::Metric).void }
  def initialize(obj); end
end

class Temporalio::Internal::Worker::WorkflowInstance::ReplaySafeMetric::Meter < Temporalio::Metric::Meter
  extend T::Sig

  sig { params(obj: Temporalio::Metric::Meter).void }
  def initialize(obj); end
end
