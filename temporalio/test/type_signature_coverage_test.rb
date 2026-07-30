# frozen_string_literal: true

require 'minitest/autorun'
require 'pathname'

class TypeSignatureCoverageTest < Minitest::Test
  ROOT = Pathname.new(File.expand_path('..', __dir__ || raise))
  LIB_ROOT = ROOT.join('lib')
  RBI_ROOT = ROOT.join('rbi')
  SIG_ROOT = ROOT.join('sig')

  def test_ruby_files_have_matching_rbs_files
    missing_paths = missing_signature_paths(SIG_ROOT, '.rbs')
    assert_empty missing_paths, "Ruby files missing RBS files:\n#{missing_paths.join("\n")}"
  end

  def test_ruby_files_have_matching_rbi_files
    missing_paths = missing_signature_paths(RBI_ROOT, '.rbi')
    assert_empty missing_paths, "Ruby files missing RBI files:\n#{missing_paths.join("\n")}"
  end

  private

  def ruby_paths
    @ruby_paths ||= relative_stems(LIB_ROOT, '**/*.rb')
  end

  def missing_signature_paths(root, extension)
    ruby_paths - relative_stems(root, "**/*#{extension}")
  end

  def relative_stems(root, pattern)
    Dir.glob(root.join(pattern).to_s).map do |path|
      Pathname.new(path).relative_path_from(root).sub_ext('').to_s
    end.sort
  end
end
