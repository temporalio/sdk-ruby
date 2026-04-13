# frozen_string_literal: true

require 'minitest/autorun'

class RbiUntypedCountTest < Minitest::Test
  RBI_PATH = File.expand_path('../rbi/temporalio.rbi', __dir__ || '')
  # Please do not increase this just to pass the test, properly type the new untyped methods.
  UNTYPED_COUNT = 167

  def test_untyped_count_does_not_increase
    rbi_content = File.read(RBI_PATH)
    actual_count = rbi_content.scan('T.untyped').size

    ratchet_count = UNTYPED_COUNT

    assert actual_count <= ratchet_count,
           "T.untyped count increased from #{ratchet_count} to #{actual_count}. " \
           'New code should use specific types instead of T.untyped.'

    return unless actual_count < ratchet_count

    warn "T.untyped count decreased from #{ratchet_count} to #{actual_count}. " \
         "Update UNTYPED_COUNT to #{actual_count} to ratchet down."
  end
end
