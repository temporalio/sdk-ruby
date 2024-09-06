# frozen_string_literal: true

module ExtraAssertions
  def assert_eventually(timeout: 10, interval: 0.2)
    start_time = Time.now
    loop do
      begin
        return yield
      rescue Minitest::Assertion => e
        raise e if Time.now - start_time > timeout
      end
      sleep(interval)
    end
  end
end
