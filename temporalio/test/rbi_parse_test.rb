# frozen_string_literal: true

require 'minitest/autorun'
require 'rbi'
require 'support/rbi_paths'

class RbiParseTest < Minitest::Test
  def test_all_rbi_files_parse
    paths = RbiPaths.all

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
