# frozen_string_literal: true

require 'temporalio/workflow'

module Temporalio
  module Workflow
    # Asynchronous future for use in workflows to do concurrent and background work. This can only be used inside
    # workflows.
    class Future
      # Return a future that completes when any of the given futures complete. The returned future will return the first
      # completed future's value or raise the first completed future's exception. To not raise the exception, see
      # {try_any_of}.
      #
      # @param futures [Array<Future<Object>>] Futures to wait for the first to complete.
      # @return [Future<Object>] Future that relays the first completed future's result/failure.
      def self.any_of(*futures)
        Future.new do
          Workflow.wait_condition(cancellation: nil) { futures.any?(&:done?) }
          # We know a future is always returned from find, the || just helps type checker
          (futures.find(&:done?) || raise).wait
        end
      end

      # Return a future that completes when all of the given futures complete or any future fails. The returned future
      # will return nil on success or raise an exception if any of the futures failed. This means if any future fails,
      # this will not wait for the other futures to complete. To wait for all futures to complete no matter what, see
      # {try_all_of}.
      #
      # @param futures [Array<Future<Object>>] Futures to wait for all to complete (or first to fail).
      # @return [Future<nil>] Future that completes successfully with nil when all futures complete, or raises on first
      #   future failure.
      def self.all_of(*futures)
        Future.new do
          Workflow.wait_condition(cancellation: nil) { futures.all?(&:done?) || futures.any?(&:failure?) }
          # Raise on error if any
          futures.find(&:failure?)&.wait
          nil
        end
      end

      # Return a future that completes when the first future completes. The result of the future is the future from the
      # list that completed first. The future returned will never raise even if the first completed future fails.
      #
      # @param futures [Array<Future<Object>>] Futures to wait for the first to complete.
      # @return [Future<Future<Object>>] Future with the first completing future regardless of success/fail.
      def self.try_any_of(*futures)
        Future.new do
          Workflow.wait_condition(cancellation: nil) { futures.any?(&:done?) }
          futures.find(&:done?) || raise
        end
      end

      # Return a future that completes when all of the given futures complete regardless of success/fail. The returned
      # future will return nil when all futures are complete.
      #
      # @param futures [Array<Future<Object>>] Futures to wait for all to complete (regardless of success/fail).
      # @return [Future<nil>] Future that completes successfully with nil when all futures complete.
      def self.try_all_of(*futures)
        Future.new do
          Workflow.wait_condition(cancellation: nil) { futures.all?(&:done?) }
          nil
        end
      end

      # @return [Object, nil] Result if the future is done or nil if it is not. This will return nil if the result is
      #   nil too. Users can use {done?} to differentiate the situations.
      attr_reader :result

      # @return [Exception, nil] Failure if this future failed or nil if it didn't or hasn't yet completed.
      attr_reader :failure

      # Create a new future. If created with a block, the block is started in the background and its success/raise is
      # the result of the future. If created without a block, the result or failure can be set on it.
      def initialize(&block)
        @done = false
        @result = nil
        @failure = nil
        @block_given = block_given?
        return unless block_given?

        @fiber = Fiber.schedule do
          @result = block.call # steep:ignore
        rescue Exception => e # rubocop:disable Lint/RescueException
          @failure = e
        ensure
          @done = true
        end
      end

      # @return [Boolean] True if the future is done, false otherwise.
      def done?
        @done
      end

      # @return [Boolean] True if done and not a failure, false if still running or failed.
      def result?
        done? && !failure
      end

      # Mark the future as done and set the result. Does nothing if the future is already done. This cannot be invoked
      # if the future was constructed with a block.
      #
      # @param result [Object] The result, which can be nil.
      def result=(result)
        Kernel.raise 'Cannot set result if block given in constructor' if @block_given
        return if done?

        @result = result
        @done = true
      end

      # @return [Boolean] True if done and failed, false if still running or succeeded.
      def failure?
        done? && !failure.nil?
      end

      # Mark the future as done and set the failure. Does nothing if the future is already done. This cannot be invoked
      # if the future was constructed with a block.
      #
      # @param failure [Exception] The failure.
      def failure=(failure)
        Kernel.raise 'Cannot set result if block given in constructor' if @block_given
        Kernel.raise 'Cannot set nil failure' if failure.nil?
        return if done?

        @failure = failure
        @done = true
      end

      # Wait on the future to complete. This will return the success or raise the failure. To not raise, use
      # {wait_no_raise}.
      #
      # @return [Object] Result on success.
      # @raise [Exception] Failure if occurred.
      def wait
        Workflow.wait_condition(cancellation: nil) { done? }
        Kernel.raise failure if failure? # steep:ignore

        result #: untyped
      end

      # Wait on the future to complete. This will return the success or nil if it failed, this will not raise.
      #
      # @return [Object, nil] Result on success or nil on failure.
      def wait_no_raise
        Workflow.wait_condition(cancellation: nil) { done? }
        result
      end
    end
  end
end
