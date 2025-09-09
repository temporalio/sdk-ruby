# frozen_string_literal: true

require 'temporalio'
require 'temporalio/cancellation'
require 'temporalio/error'
require 'temporalio/internal/worker/workflow_instance'
require 'temporalio/workflow'
require 'timeout'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Deterministic {::Fiber::Scheduler} implementation.
        class Scheduler
          def initialize(instance)
            @instance = instance
            @fibers = []
            @ready = []
            @wait_conditions = {}
            @wait_condition_counter = 0
          end

          def context
            @instance.context
          end

          def run_until_all_yielded
            loop do
              # Run all fibers until all yielded
              while (fiber = @ready.shift)
                fiber.resume
              end

              # Find the _first_ resolvable wait condition and if there, resolve it, and loop again, otherwise return.
              # It is important that we both let fibers get all settled _before_ this and only allow a _single_ wait
              # condition to be satisfied before looping. This allows wait condition users to trust that the line of
              # code after the wait condition still has the condition satisfied.
              # @type var cond_fiber: Fiber?
              cond_fiber = nil
              cond_result = nil
              @wait_conditions.each do |seq, cond|
                # Evaluate condition or skip if not true
                next unless (cond_result = cond.first.call)

                # There have been reports of this fiber being completed already, so we make sure not to process if it
                # has, but we still delete it
                deleted_cond = @wait_conditions.delete(seq)
                next unless deleted_cond&.last&.alive?

                cond_fiber = deleted_cond.last
                break
              end
              return unless cond_fiber

              cond_fiber.resume(cond_result)
            end
          end

          def evict_and_drain_all_fibers
            # Clear wait conditions
            @wait_conditions.clear

            # Just run forever, we expect the caller to deadlock timeout
            ex = Workflow::BeingEvictedError.new
            until @fibers.empty?
              # Raise a being-evicted error into every fiber. We dupe the array since it can technically be mutated
              # elsewhere.
              @fibers.dup.each do |fiber|
                next unless fiber.alive?

                fiber.raise(ex)
                fiber.resume
              rescue SystemExit, Interrupt
                # Ignore these specifically, not concerned with cleaning up fibers in this situation
                raise
              rescue Exception # rubocop:disable Lint/RescueException
                # Ignore all other exceptions
              ensure
                @fibers.delete(fiber) unless fiber.alive?
              end

              # Go over ready fibers and resume them too
              while (fiber = @ready.shift)
                begin
                  next unless fiber.alive?

                  fiber.resume
                rescue SystemExit, Interrupt
                  # Ignore these specifically, not concerned with cleaning up fibers in this situation
                  raise
                rescue Exception # rubocop:disable Lint/RescueException
                  # Ignore all other exceptions
                ensure
                  @fibers.delete(fiber) unless fiber.alive?
                end
              end
            end
          end

          def wait_condition(cancellation:, &block)
            raise Workflow::InvalidWorkflowStateError, 'Cannot wait in this context' if @instance.context_frozen

            if cancellation&.canceled?
              raise Error::CanceledError,
                    cancellation.canceled_reason || 'Wait condition canceled before started'
            end

            seq = (@wait_condition_counter += 1)
            @wait_conditions[seq] = [block, Fiber.current]

            # Add a cancellation callback
            cancel_callback_key = cancellation&.add_cancel_callback do
              # Only if the condition is still present
              cond = @wait_conditions.delete(seq)
              if cond&.last&.alive?
                cond&.last&.raise(Error::CanceledError.new(cancellation&.canceled_reason || 'Wait condition canceled'))
              end
            end

            # This blocks until a resume is called on this fiber
            result = Fiber.yield

            # Remove cancellation callback (only needed on success)
            cancellation&.remove_cancel_callback(cancel_callback_key) if cancel_callback_key

            result
          end

          def stack_trace
            # Collect backtraces of known fibers, separating with a blank line. We make sure to remove any lines that
            # reference Temporal paths, and we remove any empty backtraces.
            dir_path = @instance.illegal_call_tracing_disabled { File.dirname(Temporalio._root_file_path) }
            @fibers.map do |fiber|
              fiber.backtrace.reject { |s| s.start_with?(dir_path) }.join("\n")
            end.reject(&:empty?).join("\n\n")
          end

          ###
          # Fiber::Scheduler methods
          #
          # Note, we do not implement many methods here such as io_read and
          # such. While it might seem to make sense to implement them and
          # raise, we actually want to default to the blocking behavior of them
          # not being present. This is so advanced things like logging still
          # work inside of workflows. So we only implement the bare minimum.
          ###

          def block(_blocker, timeout = nil)
            # TODO(cretz): Make the blocker visible in the stack trace?

            # We just yield because unblock will resume this. We will just wrap in timeout if needed.
            if timeout
              begin
                Workflow.timeout(timeout) { Fiber.yield }
                true
              rescue Timeout::Error
                false
              end
            else
              Fiber.yield
              true
            end
          end

          def close
            # Nothing to do here, lifetime of scheduler is controlled by the instance
          end

          def fiber(&block)
            if @instance.context_frozen
              raise Workflow::InvalidWorkflowStateError, 'Cannot schedule fibers in this context'
            end

            fiber = Fiber.new do
              block.call # steep:ignore
            ensure
              @fibers.delete(Fiber.current)
            end
            @fibers << fiber
            @ready << fiber
            fiber
          end

          def io_wait(io, events, timeout)
            # Do not allow if IO disabled
            unless @instance.io_enabled
              raise Workflow::NondeterminismError,
                    'Cannot perform IO from inside a workflow. If this is known to be safe, ' \
                    'the code can be run in a Temporalio::Workflow::Unsafe.durable_scheduler_disabled ' \
                    'or Temporalio::Workflow::Unsafe.io_enabled block.'
            end

            # Use regular Ruby behavior of blocking this thread. There is no Ruby implementation of io_wait we can just
            # delegate to at this time (or default scheduler or anything like that), so we had to implement this
            # ourselves.
            readers = events.nobits?(IO::READABLE) ? nil : [io]
            writers = events.nobits?(IO::WRITABLE) ? nil : [io]
            priority = events.nobits?(IO::PRIORITY) ? nil : [io]
            ready = IO.select(readers, writers, priority, timeout) # steep:ignore

            result = 0
            unless ready.nil?
              result |= IO::READABLE if ready[0]&.include?(io)
              result |= IO::WRITABLE if ready[1]&.include?(io)
              result |= IO::PRIORITY if ready[2]&.include?(io)
            end
            result
          end

          def kernel_sleep(duration = nil)
            Workflow.sleep(duration)
          end

          def process_wait(pid, flags)
            raise NotImplementedError, 'Cannot wait on other processes in workflows'
          end

          def timeout_after(duration, exception_class, *exception_arguments, &)
            context.timeout(duration, exception_class, *exception_arguments, summary: 'Timeout timer', &)
          end

          def unblock(_blocker, fiber)
            @ready << fiber
          end
        end
      end
    end
  end
end
