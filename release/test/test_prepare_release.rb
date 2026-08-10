# frozen_string_literal: true

# Unit tests for scripts/prepare_release.rb.
#
# Uses minitest + minitest-mock, declared in the neighboring release/Gemfile.
# From release/:
#   bundle install
#   bundle exec ruby test/test_prepare_release.rb

require 'date'
require 'minitest/autorun'
require 'minitest/mock'
require 'pathname'
require 'set'

require_relative '../scripts/prepare_release'

class TestPrepareRelease < Minitest::Test
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

  def test_finalize_changelog_release_rolls_unreleased_into_dated_section
    text = <<~MD
      # Changelog

      ## [Unreleased]

      ### Added

      - New feature X.

      ### Fixed

      - Fixed bug Y.

      ## [v1.5.0] - 2026-06-11

      ### Added

      - Prior release note.
    MD
    updated = PrepareRelease.finalize_changelog_release(
      text, version: '1.6.0', release_date: Date.new(2026, 8, 1)
    )

    # New [Unreleased] block is present, with all headers seeded empty.
    assert_match(/^## \[Unreleased\]$/, updated)
    PrepareRelease::CHANGELOG_HEADERS.each { |h| assert_includes updated, "### #{h}" }

    # Dated release section with v prefix contains only the non-empty
    # sections we had populated.
    assert_match(/^## \[v1\.6\.0\] - 2026-08-01$/, updated)
    assert_includes updated, '- New feature X.'
    assert_includes updated, '- Fixed bug Y.'

    # Prior release section untouched.
    assert_includes updated, '## [v1.5.0] - 2026-06-11'
    assert_includes updated, '- Prior release note.'

    # Only non-empty headers made it into the dated section.
    dated_start = updated.index('## [v1.6.0]')
    dated_end   = updated.index('## [v1.5.0]')
    dated_section = updated[dated_start...dated_end]
    refute_includes dated_section, '### Deprecated'
    refute_includes dated_section, '### Security'
  end

  def test_finalize_changelog_release_refuses_empty_unreleased
    text = <<~MD
      # Changelog

      ## [Unreleased]

      ### Added

      ## [v1.5.0] - 2026-06-11
    MD
    assert_raises(RuntimeError) do
      PrepareRelease.finalize_changelog_release(
        text, version: '1.6.0', release_date: Date.new(2026, 8, 1)
      )
    end
  end

  def test_finalize_changelog_release_refuses_missing_unreleased
    text = "# Changelog\n\n## [v1.5.0] - 2026-06-11\n\n### Added\n- prior\n"
    assert_raises(RuntimeError) do
      PrepareRelease.finalize_changelog_release(
        text, version: '1.6.0', release_date: Date.new(2026, 8, 1)
      )
    end
  end

  def test_finalize_changelog_release_refuses_duplicate_version_section
    text = <<~MD
      # Changelog

      ## [Unreleased]

      ### Added

      - something

      ## [v1.6.0] - 2026-06-01

      - already released
    MD
    assert_raises(RuntimeError) do
      PrepareRelease.finalize_changelog_release(
        text, version: '1.6.0', release_date: Date.new(2026, 8, 1)
      )
    end
  end

  def test_branch_name
    assert_equal 'chore/release-1.6.1', PrepareRelease.branch_name('1.6.1')
  end

  # --- git / gh side-effect helpers ------------------------------------------
  # Mirrors sdk-python's pattern: stub the subprocess wrapper to record calls
  # instead of executing them, then assert on the captured args.

  REPO = Pathname.new('/repo').freeze

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
          [['git', 'switch', '--create', 'chore/release-1.6.1', 'origin/main'], REPO, true]
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
          [['git', 'switch', '--create', 'chore/release-1.6.1', 'origin/gmt/ruby-auto-release'], REPO, true]
        ],
        calls
      )
    end
  end

  def test_create_release_branch_rejects_non_origin_base_ref
    err = assert_raises(RuntimeError) do
      PrepareRelease.create_release_branch('1.6.1', base_ref: 'main', cwd: REPO)
    end
    assert_match(/origin\//, err.message)
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
          '--body', 'Prepare release 1.6.1.'
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
end
