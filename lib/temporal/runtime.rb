require 'singleton'
require 'temporal/bridge'

module Temporal
  class Runtime
    include Singleton

    attr_reader :core_runtime

    def initialize
      @core_runtime = Temporal::Bridge::Runtime.init
    end

    def ensure_callback_loop
      return if @thread

      @thread = Thread.new do
        core_runtime.run_callback_loop
      end
    end
  end
end
