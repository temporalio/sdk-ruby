# frozen_string_literal: true

require 'minitest/autorun'
require 'support/rbi_paths'

class RbiUntypedCountTest < Minitest::Test
  # Please do not increase this just to pass the test. Use concrete types where possible.
  ANYTHING_COUNT = 31

  # Data class initializers cannot be easily typed and are expected to use `T.untyped`
  ALLOWED_UNTYPED_PATTERNS = [
    /sig \{ params\(args: T\.untyped\)\.returns\(/,
    /sig \{ params\(kwargs: T\.untyped\)\.returns\(/
  ].freeze

  def test_untyped_usage_is_limited_to_data_constructor_shapes
    unexpected = RbiPaths.manual.flat_map do |path|
      File.readlines(path).each_with_index.filter_map do |line, index|
        next unless line.include?('T.untyped')
        next if ALLOWED_UNTYPED_PATTERNS.any? { |pattern| line.match?(pattern) }

        "#{path}:#{index + 1}: #{line.strip}"
      end
    end

    assert_empty unexpected,
                 "Manual RBI files should only use T.untyped for Data constructor/with shapes:\n" \
                 "#{unexpected.join("\n")}"
  end

  def test_anything_count_does_not_increase
    actual_count = RbiPaths.manual.sum { |path| File.read(path).scan('T.anything').size }
    ratchet_count = ANYTHING_COUNT

    assert actual_count <= ratchet_count,
           "T.anything count increased from #{ratchet_count} to #{actual_count}. " \
           'Use concrete types instead of T.anything where possible.'

    return unless actual_count < ratchet_count

    warn "T.anything count decreased from #{ratchet_count} to #{actual_count}. " \
         "Update ANYTHING_COUNT to #{actual_count} to ratchet down."
  end
end
