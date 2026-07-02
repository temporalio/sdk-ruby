# frozen_string_literal: true

require 'temporalio'
require 'temporalio/cancellation'
require 'temporalio/error'
require 'temporalio/internal/google_protobuf'
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
            @thread_blocking_fibers = {}
            @thread_blocking_mutex = Mutex.new
            @thread_blocking_condition = ConditionVariable.new
            @workflow_thread = nil
          end

          def context
            @instance.context
          end

          def run_until_all_yielded
            @workflow_thread = Thread.current
            loop do
              # Run all fibers until all yielded
              while (fiber = @ready.shift)
                fiber.resume
              end

              # Thread-blocking fibers are not durable workflow yields. Wait for them to unblock before satisfying any
              # wait condition so the condition sees the workflow after all runnable work has settled.
              next if wait_for_thread_blocking_fiber

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
          ensure
            @workflow_thread = nil
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
            result = begin
              Fiber.yield
            ensure
              # Remove pending
              @wait_conditions.delete(seq)
            end

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

          def block(blocker, timeout = nil)
            # TODO(cretz): Make the blocker visible in the stack trace?

            # Protobuf's object cache uses a process-local Mutex. We allowlist that Mutex use, but it is not a durable
            # workflow yield: if it blocks the only runnable workflow fiber, the workflow task must remain blocked so
            # deadlock detection can fail it instead of completing a partial command set.
            if timeout.nil? && thread_blocking_protobuf_mutex_wait?(blocker)
              fiber = Fiber.current
              synchronize_thread_blocking_fibers { @thread_blocking_fibers[fiber] = true }
              begin
                Fiber.yield
                return true
              ensure
                synchronize_thread_blocking_fibers do
                  @thread_blocking_fibers.delete(fiber)
                  @thread_blocking_condition.broadcast
                end
              end
            end

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

          def fiber_interrupt(fiber, exception)
            fiber.raise(exception) if fiber.alive?
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
            synchronize_thread_blocking_fibers do
              @thread_blocking_fibers.delete(fiber)
              @ready << fiber
              @thread_blocking_condition.broadcast
            end
          end

          private

          def thread_blocking_protobuf_mutex_wait?(blocker)
            blocker.is_a?(::Mutex) &&
              ::Temporalio::Internal::GoogleProtobuf.in_call_stack?(caller_locations)
          end

          def wait_for_thread_blocking_fiber
            synchronize_thread_blocking_fibers do
              return true unless @ready.empty?
              return false if @thread_blocking_fibers.empty?

              @thread_blocking_condition.wait(@thread_blocking_mutex) while @ready.empty? &&
                                                                            !@thread_blocking_fibers.empty?
              true
            end
          end

          def synchronize_thread_blocking_fibers(&)
            if Thread.current == @workflow_thread
              with_workflow_scheduler_disabled do
                @thread_blocking_mutex.synchronize(&)
              end
            else
              @thread_blocking_mutex.synchronize(&)
            end
          end

          def with_workflow_scheduler_disabled
            previous_scheduler = Fiber.scheduler
            @instance.illegal_call_tracing_disabled do
              Fiber.set_scheduler(nil)
              yield
            ensure
              Fiber.set_scheduler(previous_scheduler)
            end
          end
        end
      end
    end
  end
end
