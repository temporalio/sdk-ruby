# frozen_string_literal: true

require 'temporalio/scoped_logger'
require 'test_base'

class ScopedLoggerTest < TestBase
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
end
