# frozen_string_literal: true

require 'temporalio/error'

module Temporalio
  # Cancellation representation, often known as a "cancellation token". This is used by clients, activities, and
  # workflows to represent cancellation in a thread/fiber-safe way.
  class Cancellation
    # Create a new cancellation.
    #
    # This is usually created and destructured into a tuple with the second value being the proc to invoke to cancel.
    # For example: `cancel, cancel_proc = Temporalio::Cancellation.new`. This is done via {to_ary} which returns a proc
    # to issue the cancellation in the second value of the array.
    #
    # @param parents [Array<Cancellation>] Parent cancellations to link this one to. This cancellation will be canceled
    #   when any parents are canceled.
    def initialize(*parents)
      @canceled = false
      @canceled_reason = nil
      @canceled_mutex = Mutex.new
      @canceled_cond_var = nil
      @cancel_callbacks = []
      @shield_depth = 0
      @shield_pending_cancel = nil # When pending, set as single-reason array
      parents.each { |p| p.add_cancel_callback { on_cancel(reason: p.canceled_reason) } }
    end

    # @return [Boolean] Whether this cancellation is canceled.
    def canceled?
      @canceled_mutex.synchronize { @canceled }
    end

    # @return [String, nil] Reason for cancellation. Can be nil if not canceled or no reason provided.
    def canceled_reason
      @canceled_mutex.synchronize { @canceled_reason }
    end

    # @return [Boolean] Whether a cancel is pending but currently shielded.
    def pending_canceled?
      @canceled_mutex.synchronize { !@shield_pending_cancel.nil? }
    end

    # @return [String, nil] Reason for pending cancellation. Can be nil if not pending canceled or no reason provided.
    def pending_canceled_reason
      @canceled_mutex.synchronize { @shield_pending_cancel&.first }
    end

    # Raise an error if this cancellation is canceled.
    #
    # @param err [Exception] Error to raise.
    def check!(err = Error::CanceledError.new('Canceled'))
      raise err if canceled?
    end

    # @return [Array(Cancellation, Proc)] Self and a proc to call to cancel that accepts an optional string `reason`
    #   keyword argument. As a general practice, only the creator of the cancellation should be the one controlling its
    #   cancellation.
    def to_ary
      [self, proc { |reason: nil| on_cancel(reason:) }]
    end

    # Wait on this to be canceled. This is backed by a {::ConditionVariable}.
    def wait
      @canceled_mutex.synchronize do
        break if @canceled

        # Add cond var if not present
        if @canceled_cond_var.nil?
          @canceled_cond_var = ConditionVariable.new
          @cancel_callbacks.push(proc { @canceled_mutex.synchronize { @canceled_cond_var.broadcast } })
        end

        # Wait on it
        @canceled_cond_var.wait(@canceled_mutex)
      end
    end

    # Shield the given block from cancellation. This means any cancellation that occurs while shielded code is running
    # will be set as "pending" and will not take effect until after the block completes. If shield calls are nested, the
    # cancellation remains "pending" until the last shielded block ends.
    #
    # @yield Requires a block to run under shield.
    # @return [Object] Result of the block.
    def shield
      raise ArgumentError, 'Block required' unless block_given?

      @canceled_mutex.synchronize { @shield_depth += 1 }
      yield
    ensure
      callbacks_to_run = @canceled_mutex.synchronize do
        @shield_depth -= 1
        if @shield_depth.zero? && @shield_pending_cancel
          reason = @shield_pending_cancel.first
          @shield_pending_cancel = nil
          prepare_cancel(reason:)
        end
      end
      callbacks_to_run&.each(&:call)
    end

    # Advanced call to invoke a proc or block on cancel. The callback usually needs to be quick and thread-safe since it
    # is called in the canceler's thread. Usually the callback will just be something like pushing on a queue or
    # signaling a condition variable. If the cancellation is already canceled, the callback is called inline before
    # returning.
    #
    # @note WARNING: This is advanced API, users should use {wait} or similar.
    #
    # @param proc [Proc, nil] Proc to invoke, or nil to use block.
    # @yield Accepts block if not using `proc`.
    def add_cancel_callback(proc = nil, &block)
      raise ArgumentError, 'Must provide proc or block' unless proc || block
      raise ArgumentError, 'Cannot provide both proc and block' if proc && block
      raise ArgumentError, 'Parameter not a proc' if proc && !proc.is_a?(Proc)

      callback_to_run_immediately = @canceled_mutex.synchronize do
        callback = proc || block
        @cancel_callbacks.push(proc || block)
        break nil unless @canceled

        callback
      end
      callback_to_run_immediately&.call
      nil
    end

    private

    def on_cancel(reason:)
      callbacks_to_run = @canceled_mutex.synchronize do
        # If we're shielding, set as pending and return nil
        if @shield_depth.positive?
          @shield_pending_cancel = [reason]
          nil
        else
          prepare_cancel(reason:)
        end
      end
      callbacks_to_run&.each(&:call)
    end

    # Expects to be called inside mutex by caller, returns callbacks to run
    def prepare_cancel(reason:)
      return nil if @canceled

      @canceled = true
      @canceled_reason = reason
      @cancel_callbacks.dup
    end
  end
end
