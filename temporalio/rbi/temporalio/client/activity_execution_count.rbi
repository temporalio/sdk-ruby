# typed: true

class Temporalio::Client::ActivityExecutionCount
  sig { params(count: Integer, groups: T::Array[Temporalio::Client::ActivityExecutionCount::AggregationGroup]).void }
  def initialize(count, groups); end

  sig { returns(Integer) }
  attr_reader :count

  sig { returns(T::Array[Temporalio::Client::ActivityExecutionCount::AggregationGroup]) }
  attr_reader :groups
end

class Temporalio::Client::ActivityExecutionCount::AggregationGroup
  sig { params(count: Integer, group_values: T::Array[T.nilable(Object)]).void }
  def initialize(count, group_values); end

  sig { returns(Integer) }
  attr_reader :count

  sig { returns(T::Array[T.nilable(Object)]) }
  attr_reader :group_values
end
