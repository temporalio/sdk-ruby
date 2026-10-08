# frozen_string_literal: true

# rubocop:disable Style/Documentation, Style/DocumentationMethod

# Unit tests for extra/release/scripts/prepare_release.rb.

require 'date'
require 'minitest/autorun'
require 'minitest/mock'
require 'pathname'

require_relative '../scripts/prepare_release'

class TestPrepareRelease < Minitest::Test
  REPO = Pathname.new('/repo').freeze

  def test_validate_version_accepts_semver_shapes
    assert_equal '1.6.0',     PrepareRelease.validate_version('1.6.0')
    assert_equal '1.30.0',    PrepareRelease.validate_version('1.30.0')
    assert_equal '1.6.0.rc1', PrepareRelease.validate_version('1.6.0.rc1')
    assert_equal '1.6.0-rc1', PrepareRelease.validate_version('1.6.0-rc1')
  end

  def test_validate_version_rejects_v_prefix
    assert_raises(ArgumentError) { PrepareRelease.validate_version('v1.6.0') }
  end

  def test_validate_version_rejects_garbage
    assert_raises(ArgumentError) { PrepareRelease.validate_version('') }
    assert_raises(ArgumentError) { PrepareRelease.validate_version('1') }
    assert_raises(ArgumentError) { PrepareRelease.validate_version('abc') }
  end

  def test_parse_date_accepts_iso
    assert_equal Date.new(2026, 8, 1), PrepareRelease.parse_date('2026-08-01')
  end

  def test_parse_date_rejects_non_iso
    assert_raises(ArgumentError) { PrepareRelease.parse_date('August 1, 2026') }
  end

  def test_replace_version_constant_single_quoted
    text = <<~RB
      # frozen_string_literal: true

      module Temporalio
        VERSION = '1.6.0'
      end
    RB
    expected = <<~RB
      # frozen_string_literal: true

      module Temporalio
        VERSION = '1.6.1'
      end
    RB
    assert_equal expected, PrepareRelease.replace_version_constant(text, '1.6.1')
  end

  def test_replace_version_constant_double_quoted_preserves_quotes
    text = "module Temporalio\n  VERSION = \"1.6.0\"\nend\n"
    expected = "module Temporalio\n  VERSION = \"1.6.1\"\nend\n"
    assert_equal expected, PrepareRelease.replace_version_constant(text, '1.6.1')
  end

  def test_replace_version_constant_raises_when_missing
    assert_raises(RuntimeError) do
      PrepareRelease.replace_version_constant("module Temporalio\nend\n", '1.6.1')
    end
  end

  def test_branch_name
    assert_equal 'chore/release-1.6.1', PrepareRelease.branch_name('1.6.1')
  end

  # --- git / gh side-effect helpers ------------------------------------------
  # Mirrors sdk-python's pattern: stub the subprocess wrapper to record calls
  # instead of executing them, then assert on the captured args.

  # Run block with PrepareRelease.run stubbed. Yields the calls array; each
  # entry is [cmd, cwd, check].
  def with_recorded_run
    calls = []
    recorder = lambda do |cmd, cwd: nil, check: true|
      calls << [cmd, cwd, check]
      nil
    end
    PrepareRelease.stub(:run, recorder) do
      yield calls
    end
  end

  def test_create_release_branch_fetches_main_and_switches_from_it
    with_recorded_run do |calls|
      PrepareRelease.create_release_branch('1.6.1', cwd: REPO)
      assert_equal(
        [
          [%w[git fetch origin main], REPO, true],
          [['git', 'switch', '--create', 'chore/release-1.6.1', 'origin/main'], REPO, true],
          [%w[git submodule update --init --recursive], REPO, true]
        ],
        calls
      )
    end
  end

  def test_create_release_branch_with_alternate_base_ref
    with_recorded_run do |calls|
      PrepareRelease.create_release_branch(
        '1.6.1',
        base_ref: 'origin/gmt/ruby-auto-release',
        cwd: REPO
      )
      assert_equal(
        [
          [%w[git fetch origin gmt/ruby-auto-release], REPO, true],
          [['git', 'switch', '--create', 'chore/release-1.6.1', 'origin/gmt/ruby-auto-release'], REPO, true],
          [%w[git submodule update --init --recursive], REPO, true]
        ],
        calls
      )
    end
  end

  def test_create_release_branch_rejects_non_origin_base_ref
    err = assert_raises(RuntimeError) do
      PrepareRelease.create_release_branch('1.6.1', base_ref: 'main', cwd: REPO)
    end
    assert_match(%r{origin/}, err.message)
  end

  def test_commit_release_changes_commits_only_release_files
    with_recorded_run do |calls|
      PrepareRelease.commit_release_changes('1.6.1', cwd: REPO)
      assert_equal 1, calls.length
      assert_equal(
        ['git', 'commit', '-m', 'Prepare release 1.6.1', '--', *PrepareRelease::RELEASE_FILES],
        calls[0][0]
      )
      assert_equal REPO, calls[0][1]
    end
  end

  def test_push_release_branch_pushes_versioned_branch
    with_recorded_run do |calls|
      PrepareRelease.push_release_branch('1.6.1', cwd: REPO)
      assert_equal(
        [[['git', 'push', '--set-upstream', 'origin', 'chore/release-1.6.1'], REPO, true]],
        calls
      )
    end
  end

  def test_commit_release_changes_includes_consumed_fragments
    with_recorded_run do |calls|
      fragment = 'changelog/fixed/dancing-teapot.md'
      PrepareRelease.commit_release_changes('1.6.1', cwd: REPO, consumed_paths: [fragment])
      assert_equal fragment, calls[0][0].last
    end
  end

  def test_create_release_pr_uses_versioned_branch
    with_recorded_run do |calls|
      PrepareRelease.create_release_pr('1.6.1', cwd: REPO)
      assert_equal 1, calls.length
      assert_equal(
        [
          'gh', 'pr', 'create',
          '--base', 'main',
          '--head', 'chore/release-1.6.1',
          '--title', 'Prepare release 1.6.1',
          '--body', 'Prepare release 1.6.1.',
          '--label', 'skip-changelog'
        ],
        calls[0][0]
      )
      assert_equal REPO, calls[0][1]
    end
  end

  def test_ensure_clean_worktree_passes_on_clean
    PrepareRelease.stub(:changed_files, Set.new) do
      PrepareRelease.ensure_clean_worktree(cwd: REPO) # must not raise
    end
  end

  def test_ensure_clean_worktree_rejects_existing_changes
    PrepareRelease.stub(:changed_files, Set.new(['CHANGELOG.md', 'other.rb'])) do
      err = assert_raises(RuntimeError) { PrepareRelease.ensure_clean_worktree(cwd: REPO) }
      assert_match(/clean worktree/, err.message)
      assert_match(/CHANGELOG\.md/, err.message)
      assert_match(/other\.rb/, err.message)
    end
  end

  def test_ensure_only_release_changes_passes_with_only_allowed_files
    PrepareRelease.stub(:changed_files, Set.new(PrepareRelease::RELEASE_FILES)) do
      PrepareRelease.ensure_only_release_changes(cwd: REPO) # must not raise
    end
  end

  def test_ensure_only_release_changes_rejects_unexpected_files
    dirty = Set.new(PrepareRelease::RELEASE_FILES + ['unrelated.txt'])
    PrepareRelease.stub(:changed_files, dirty) do
      err = assert_raises(RuntimeError) { PrepareRelease.ensure_only_release_changes(cwd: REPO) }
      assert_match(/unexpected files/, err.message)
      assert_match(/unrelated\.txt/, err.message)
    end
  end

  def test_ensure_only_release_changes_allows_consumed_fragments
    fragment = 'changelog/fixed/dancing-teapot.md'
    PrepareRelease.stub(:changed_files, Set.new(PrepareRelease::RELEASE_FILES + [fragment])) do
      PrepareRelease.ensure_only_release_changes(cwd: REPO, consumed_paths: [fragment])
      assert_raises(RuntimeError) { PrepareRelease.ensure_only_release_changes(cwd: REPO) }
    end
  end
end

# rubocop:enable Style/Documentation, Style/DocumentationMethod
