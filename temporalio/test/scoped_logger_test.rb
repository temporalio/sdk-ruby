# frozen_string_literal: true

require 'semantic_logger'
require 'temporalio/scoped_logger'
require 'test'

class ScopedLoggerTest < Test
  # Minimal logger-ish object whose level is whatever we want it to be.
  class CustomLevelLogger
    attr_reader :level

    def initialize(level)
      @level = level
    end

    def add(severity, message = nil, progname = nil); end
  end

  def test_logger_with_values
    # Default doesn't change anything
    out, = safe_capture_io do
      logger = Temporalio::ScopedLogger.new(Logger.new($stdout, level: Logger::INFO))
      logger.info('info1')
      logger.error('error1')
      logger.debug('debug1')
      logger.with_level(Logger::DEBUG) { logger.debug('debug2') } # steep:ignore
      logger.error(RuntimeError.new('exception1'))
    end
    lines = out.split("\n")
    assert(lines.one? { |l| l.include?('INFO') && l.end_with?('info1') })
    assert(lines.one? { |l| l.include?('ERROR') && l.end_with?('error1') })
    assert(lines.none? { |l| l.include?('debug1') })
    assert(lines.one? { |l| l.include?('DEBUG') && l.end_with?('debug2') })
    assert(lines.one? { |l| l.include?('ERROR') && l.end_with?('exception1 (RuntimeError)') })

    # With a getter that returns some values
    extra_vals = { some_key: { foo: 'bar', 'baz' => 123 } }
    out, = safe_capture_io do
      logger = Temporalio::ScopedLogger.new(Logger.new($stdout, level: Logger::INFO))
      logger.scoped_values_getter = proc { extra_vals }
      logger.add(Logger::WARN, 'warn1')
      logger.info('info1')
      logger.error('error1')
      logger.debug('debug1')
      logger.with_level(Logger::DEBUG) { logger.debug('debug2') } # steep:ignore
      logger.error(RuntimeError.new('exception1'))
    end
    lines = out.split("\n")
    assert(lines.one? { |l| l.include?('INFO') && l.end_with?("info1 #{extra_vals.inspect}") })
    assert(lines.one? { |l| l.include?('ERROR') && l.end_with?("error1 #{extra_vals.inspect}") })
    assert(lines.none? { |l| l.include?('debug1') })
    assert(lines.one? { |l| l.include?('DEBUG') && l.end_with?("debug2 #{extra_vals.inspect}") })
    assert(lines.one? { |l| l.include?('ERROR') && l.end_with?("exception1 #{extra_vals.inspect} (RuntimeError)") })
  end

  def test_level_with_standard_logger
    [Logger::DEBUG, Logger::INFO, Logger::WARN, Logger::ERROR, Logger::FATAL, Logger::UNKNOWN].each do |level|
      logger = Temporalio::ScopedLogger.new(Logger.new(IO::NULL, level:))
      assert_instance_of(Integer, logger.level)
      assert_equal(level, logger.level)
    end

    # Logger itself accepts symbols/strings but normalizes them to integers, so those come through unchanged too
    logger = Temporalio::ScopedLogger.new(Logger.new(IO::NULL, level: :warn))
    assert_instance_of(Integer, logger.level)
    assert_equal(Logger::WARN, logger.level)
  end

  def test_level_with_semantic_logger
    {
      debug: Logger::DEBUG,
      info: Logger::INFO,
      warn: Logger::WARN,
      error: Logger::ERROR,
      fatal: Logger::FATAL
    }.each do |semantic_level, expected_level|
      inner = SemanticLogger::Logger.new('ScopedLoggerTest', semantic_level)
      # Sanity check on the premise of this test: semantic_logger reports its level as a symbol
      assert_instance_of(Symbol, inner.level)

      logger = Temporalio::ScopedLogger.new(inner)
      assert_instance_of(Integer, logger.level)
      assert_equal(expected_level, logger.level)
    end

    # semantic_logger levels with no ::Logger counterpart (e.g. :trace) fall back to UNKNOWN
    logger = Temporalio::ScopedLogger.new(SemanticLogger::Logger.new('ScopedLoggerTest', :trace))
    assert_instance_of(Integer, logger.level)
    assert_equal(Logger::UNKNOWN, logger.level)
  end

  def test_level_with_other_non_integer_levels
    # Strings are upcased and looked up just like symbols
    logger = Temporalio::ScopedLogger.new(CustomLevelLogger.new('warn'))
    assert_instance_of(Integer, logger.level)
    assert_equal(Logger::WARN, logger.level)

    # Anything unrecognized, or that cannot even be upcased, is UNKNOWN rather than an error
    ['nonsense', :nonsense, nil, 1.5, Object.new].each do |level|
      logger = Temporalio::ScopedLogger.new(CustomLevelLogger.new(level))
      assert_instance_of(Integer, logger.level)
      assert_equal(Logger::UNKNOWN, logger.level)
    end
  end

  def test_logging_with_semantic_logger
    inner = SemanticLogger::Logger.new('ScopedLoggerTest', :info)
    logger = Temporalio::ScopedLogger.new(inner)
    logger.scoped_values_getter = proc { { some_key: 'some_value' } }

    logged = []
    inner.define_singleton_method(:log) { |log| logged << log }

    logger.info('info1')
    logger.error('error1')
    logger.debug('debug1')

    assert_equal([Logger::INFO, Logger::ERROR], logged.map { |log| Logger::Severity.const_get(log.level.upcase) })
    assert(logged.none? { |log| log.message.to_s.include?('debug1') })
  end
end
