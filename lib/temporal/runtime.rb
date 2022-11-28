require 'singleton'
require 'temporal/bridge'
require 'temporal/worker/reactor'

module Temporal
  class Runtime
    include Singleton

    attr_reader :core_runtime, :reactor

    def initialize
      @core_runtime = Temporal::Bridge::Runtime.init
      @reactor = Temporal::Worker::Reactor.new
    end

    def ensure_callback_loop
      return if @thread

      @thread = Thread.new do
        core_runtime.run_callback_loop
      end
    end
  end
end
