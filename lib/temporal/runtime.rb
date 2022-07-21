require 'singleton'
require 'temporal/bridge'

module Temporal
  class Runtime
    include Singleton

    attr_reader :core_runtime

    def initialize
      @core_runtime = Temporal::Bridge::Runtime.init
    end
  end
end
