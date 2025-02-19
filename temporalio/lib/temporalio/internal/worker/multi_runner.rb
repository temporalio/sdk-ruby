# frozen_string_literal: true

require 'singleton'
require 'temporalio/internal/bridge/worker'

module Temporalio
  module Internal
    module Worker
      # Primary worker (re)actor-style event handler. This handles multiple workers, receiving events from the bridge,
      # and handling a user block.
      class MultiRunner
        def initialize(workers:, shutdown_signals:)
          @workers = workers
          @queue = Queue.new

          @shutdown_initiated_mutex = Mutex.new
          @shutdown_initiated = false

          # Trap signals to push to queue
          shutdown_signals.each do |signal|
            Signal.trap(signal) { @queue.push(Event::ShutdownSignalReceived.new) }
          end

          # Start pollers
          Bridge::Worker.async_poll_all(workers.map(&:_bridge_worker), @queue)
        end

        def apply_thread_or_fiber_block(&)
          return unless block_given?

          @thread_or_fiber = if Fiber.current_scheduler
                               Fiber.schedule do
                                 @queue.push(Event::BlockSuccess.new(result: yield))
                               rescue InjectEventForTesting => e
                                 @queue.push(e.event)
                                 @queue.push(Event::BlockSuccess.new(result: e))
                               rescue Exception => e # rubocop:disable Lint/RescueException -- Intentionally catch all
                                 @queue.push(Event::BlockFailure.new(error: e))
                               end
                             else
                               Thread.new do
                                 @queue.push(Event::BlockSuccess.new(result: yield))
                               rescue InjectEventForTesting => e
                                 @queue.push(e.event)
                                 @queue.push(Event::BlockSuccess.new(result: e))
                               rescue Exception => e # rubocop:disable Lint/RescueException -- Intentionally catch all
                                 @queue.push(Event::BlockFailure.new(error: e))
                               end
                             end
        end

        def apply_workflow_activation_decoded(workflow_worker:, activation:)
          @queue.push(Event::WorkflowActivationDecoded.new(workflow_worker:, activation:))
        end

        def apply_workflow_activation_complete(workflow_worker:, activation_completion:, encoded:)
          @queue.push(Event::WorkflowActivationComplete.new(
                        workflow_worker:, activation_completion:, encoded:, completion_complete_queue: @queue
                      ))
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
          # Queue value is one of the following:
          # * Event - non-poller event
          # * [worker index, :activity/:workflow, bytes] - poll success
          # * [worker index, :activity/:workflow, error] - poll fail
          # * [worker index, :activity/:workflow, nil] - worker shutdown
          # * [nil, nil, nil] - all pollers done
          # * [-1, run_id_string, error_or_nil] - workflow activation completion complete
          result = @queue.pop
          if result.is_a?(Event)
            result
          else
            first, second, third = result
            if first.nil? || second.nil?
              Event::AllPollersShutDown.instance
            elsif first == -1
              Event::WorkflowActivationCompletionComplete.new(run_id: second, error: third)
            else
              worker = @workers[first]
              case third
              when nil
                Event::PollerShutDown.new(worker:, worker_type: second)
              when Exception
                Event::PollFailure.new(worker:, worker_type: second, error: third)
              else
                Event::PollSuccess.new(worker:, worker_type: second, bytes: third)
              end
            end
          end
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

          class WorkflowActivationDecoded < Event
            attr_reader :workflow_worker, :activation

            def initialize(workflow_worker:, activation:) # rubocop:disable Lint/MissingSuper
              @workflow_worker = workflow_worker
              @activation = activation
            end
          end

          class WorkflowActivationComplete < Event
            attr_reader :workflow_worker, :activation_completion, :encoded, :completion_complete_queue

            def initialize(workflow_worker:, activation_completion:, encoded:, completion_complete_queue:) # rubocop:disable Lint/MissingSuper
              @workflow_worker = workflow_worker
              @activation_completion = activation_completion
              @encoded = encoded
              @completion_complete_queue = completion_complete_queue
            end
          end

          class WorkflowActivationCompletionComplete < Event
            attr_reader :run_id, :error

            def initialize(run_id:, error:) # rubocop:disable Lint/MissingSuper
              @run_id = run_id
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

          class ShutdownSignalReceived < Event
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
