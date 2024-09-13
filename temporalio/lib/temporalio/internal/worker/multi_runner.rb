# frozen_string_literal: true

require 'singleton'
require 'temporalio/internal/bridge/worker'

module Temporalio
  module Internal
    module Worker
      class MultiRunner
        def initialize(workers:)
          @workers = workers
          @queue = Queue.new

          @shutdown_initiated_mutex = Mutex.new
          @shutdown_initiated = false

          # Handle worker polls. The block can be called with one these sets:
          # * [worker index, :activity/:workflow, bytes] - poll success
          # * [worker index, :activity/:workflow, error] - poll fail
          # * [worker index, :activity/:workflow, nil] - worker shutdown
          # * [nil, nil, nil] - all pollers done
          Bridge::Worker.async_poll_all(workers.map(&:_bridge_worker)) do |worker_index, worker_type, result|
            if worker_index.nil? || worker_type.nil?
              @queue.push(Event::AllPollersShutDown.instance)
              break
            end
            worker = workers[worker_index]
            @queue.push(case result
                        when nil
                          Event::PollerShutDown.new(worker:, worker_type:)
                        when Exception
                          Event::PollFailure.new(worker:, worker_type:, error: result)
                        else
                          Event::PollSuccess.new(worker:, worker_type:, bytes: result)
                        end)
          end
        end

        def apply_thread_or_fiber_block(&)
          return unless block_given?

          @thread_or_fiber = if Fiber.current_scheduler
                               Fiber.schedule do
                                 @queue.push(Event::BlockSuccess.new(result: yield))
                               rescue InjectEventForTesting => e
                                 @queue.push(e.event)
                                 @queue.push(Event::BlockSuccess.new(result: e))
                               rescue Exception => e # rubocop:disable Lint/RescueException Intentionally catch all
                                 @queue.push(Event::BlockFailure.new(error: e))
                               end
                             else
                               Thread.new do
                                 @queue.push(Event::BlockSuccess.new(result: yield))
                               rescue InjectEventForTesting => e
                                 @queue.push(e.event)
                                 @queue.push(Event::BlockSuccess.new(result: e))
                               rescue Exception => e # rubocop:disable Lint/RescueException Intentionally catch all
                                 @queue.push(Event::BlockFailure.new(error: e))
                               end
                             end
        end

        def raise_in_thread_or_fiber_block(error)
          @thread_or_fiber&.raise(error)
        end

        # Clarify this is the only thread-safe function here
        def initiate_shutdown
          should_call = @shutdown_initiated_mutex.synchronize do
            break false if @shutdown_initiated

            @shutdown_initiated = true
          end
          return unless should_call

          @workers.each(&:_initiate_shutdown)
        end

        def wait_complete_and_finalize_shutdown
          # Wait for them all to complete
          @workers.each(&:_wait_all_complete)

          # Finalize them all
          Bridge::Worker.finalize_shutdown_all(@workers.map(&:_bridge_worker))
        end

        # Intentionally not an enumerable/enumerator since stop semantics are
        # caller determined
        def next_event
          @queue.pop
        end

        class Event
          class PollSuccess < Event
            attr_reader :worker, :worker_type, :bytes

            def initialize(worker:, worker_type:, bytes:) # rubocop:disable Lint/MissingSuper
              @worker = worker
              @worker_type = worker_type
              @bytes = bytes
            end
          end

          class PollFailure < Event
            attr_reader :worker, :worker_type, :error

            def initialize(worker:, worker_type:, error:) # rubocop:disable Lint/MissingSuper
              @worker = worker
              @worker_type = worker_type
              @error = error
            end
          end

          class PollerShutDown < Event
            attr_reader :worker, :worker_type

            def initialize(worker:, worker_type:) # rubocop:disable Lint/MissingSuper
              @worker = worker
              @worker_type = worker_type
            end
          end

          class AllPollersShutDown < Event
            include Singleton
          end

          class BlockSuccess < Event
            attr_reader :result

            def initialize(result:) # rubocop:disable Lint/MissingSuper
              @result = result
            end
          end

          class BlockFailure < Event
            attr_reader :error

            def initialize(error:) # rubocop:disable Lint/MissingSuper
              @error = error
            end
          end
        end

        class InjectEventForTesting < Temporalio::Error
          attr_reader :event

          def initialize(event)
            super('Injecting event for testing')
            @event = event
          end
        end
      end
    end
  end
end
