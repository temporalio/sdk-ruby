require 'singleton'
require 'temporalio/bridge'
require 'temporalio/worker/reactor'

module Temporalio
  class Runtime
    include Singleton

    attr_reader :core_runtime, :reactor

    def initialize
      @core_runtime = Temporalio::Bridge::Runtime.init
      @reactor = Temporalio::Worker::Reactor.new
    end

    def ensure_callback_loop
      return if @thread

      @thread = Thread.new do
        core_runtime.run_callback_loop
      end
    end
  end
end
