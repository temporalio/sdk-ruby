# frozen_string_literal: true

require 'minitest/autorun'
require 'rbi'

class RbiParseTest < Minitest::Test
  RBI_GLOB = File.expand_path('../rbi/**/*.rbi', __dir__ || '')

  def test_all_rbi_files_parse
    paths = Dir.glob(RBI_GLOB)

    assert paths.any?, 'Expected at least one RBI file'

    failures = paths.filter_map do |path|
      RBI::Parser.parse_file(path)
      nil
    rescue StandardError => e
      "#{path}: #{e.class}: #{e.message}"
    end

    assert_empty failures, "RBI parse failures:\n#{failures.join("\n")}"
  end
end
