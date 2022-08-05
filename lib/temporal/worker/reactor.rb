require 'fiber'
require 'forwardable'
require 'set'
require 'singleton'
require 'temporal/worker/reactor/promise'
require 'temporal/worker/reactor/command'

module Temporal
  class Worker
    class Reactor
      include Singleton
      extend SingleForwardable

      def_delegators :instance, :execute, :attach

      def initialize
        @queue = Queue.new
        @fibers = Set.new
        @thread = nil
        @running = false
        @mutex = Mutex.new
      end

      def execute(&block)
        mutex.synchronize do
          unless running?
            @thread = Thread.new { run_loop }
            @running = true
          end
        end

        enqueue { block.call(self) }
      end

      def async(&block)
        promise = Promise.new

        enqueue do
          fiber = Fiber.current

          resolver = lambda do |value = nil|
            resume(fiber, value)
          end

          block.call(resolver)

          value = Fiber.yield
          promise.set(value)
        end

        promise
      end

      def await(&block)
        promise = async(&block)
        promise.result
      end

      def attach
        thread&.join
      end

      private

      attr_reader :queue, :thread, :fibers, :mutex

      def running?
        @running
      end

      def run_loop
        loop do
          command = queue.pop

          handle(command)

          fibers.delete_if { |f| !f.alive? }

          mutex.synchronize do
            if queue.empty? && fibers.empty?
              @running = false
              break
            end
          end
        end
      end

      def handle(command)
        case command
        when Command::Start
          run_in_fiber(command.block)
        when Command::Resume
          command.fiber.resume(command.value) if command.fiber.alive?
        end
      end

      def run_in_fiber(block)
        fiber = Fiber.new(&block)
        fibers << fiber
        fiber.resume
      end

      def enqueue(&block)
        queue << Command::Start.new(block)
      end

      def resume(fiber, value)
        queue << Command::Resume.new(fiber, value)
      end
    end
  end
end
