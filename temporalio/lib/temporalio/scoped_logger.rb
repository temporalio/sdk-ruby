# frozen_string_literal: true

require 'delegate'
require 'logger'

module Temporalio
  # Implementation via delegator to {::Logger} that puts scoped values on the log message and appends them to the log
  # message.
  class ScopedLogger < SimpleDelegator
    # @!attribute scoped_values_getter
    #   @return [Proc, nil] Proc to call to get scoped values when needed.
    attr_accessor :scoped_values_getter

    # @!attribute scoped_values_getter
    #   @return [Boolean] Whether the scoped value appending is disabled.
    attr_accessor :disable_scoped_values

    # @see Logger.add
    def add(severity, message = nil, progname = nil)
      return true if (severity || Logger::UNKNOWN) < level
      return super if scoped_values_getter.nil? || @disable_scoped_values

      scoped_values = scoped_values_getter.call
      return super if scoped_values.nil?

      if message.nil?
        if block_given?
          message = yield
        else
          message = progname
          progname = nil
        end
      end
      # For exceptions we need to dup and append here, for everything else we
      # need to delegate to a log message
      new_message = if message.is_a?(Exception)
                      message.exception("#{message.message} #{scoped_values}")
                    else
                      LogMessage.new(message, scoped_values)
                    end
      super(severity, new_message, progname)
    end
    alias log add

    # @see Logger.debug
    def debug(progname = nil, &)
      add(Logger::DEBUG, nil, progname, &)
    end

    # @see Logger.info
    def info(progname = nil, &)
      add(Logger::INFO, nil, progname, &)
    end

    # @see Logger.warn
    def warn(progname = nil, &)
      add(Logger::WARN, nil, progname, &)
    end

    # @see Logger.error
    def error(progname = nil, &)
      add(Logger::ERROR, nil, progname, &)
    end

    # @see Logger.fatal
    def fatal(progname = nil, &)
      add(Logger::FATAL, nil, progname, &)
    end

    # @see Logger.unknown
    def unknown(progname = nil, &)
      add(Logger::UNKNOWN, nil, progname, &)
    end

    # Scoped log message wrapping original log message.
    class LogMessage
      # @return [Object] Original log message.
      attr_reader :message

      # @return [Object] Scoped values.
      attr_reader :scoped_values

      # @!visibility private
      def initialize(message, scoped_values)
        @message = message
        @scoped_values = scoped_values
      end

      # @return [String] Message with scoped values appended.
      def inspect
        message_str = message.is_a?(String) ? message : message.inspect
        "#{message_str} #{scoped_values}"
      end
    end
  end
end
