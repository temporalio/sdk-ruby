# frozen_string_literal: true

class ActiveModelConcurrentMapPattern
  def initialize
    @map = Concurrent::Map.new
  end

  def match(method_name)
    @map.compute_if_absent(method_name) { nil }
  end
end
