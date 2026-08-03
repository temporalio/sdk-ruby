# frozen_string_literal: true

# Unit tests for scripts/rollback_release.rb.
# Run with: ruby test/test_rollback_release.rb

require 'json'
require 'minitest/autorun'
require 'minitest/mock'
require 'pathname'

require_relative '../scripts/rollback_release'

class TestRollbackRelease < Minitest::Test
  REPO = Pathname.new('/repo').freeze

  # --- name derivations ------------------------------------------------------

  def test_validate_version_accepts_semver_and_rejects_v_prefix
    assert_equal '1.6.1', RollbackRelease.validate_version('1.6.1')
    assert_raises(ArgumentError) { RollbackRelease.validate_version('v1.6.1') }
    assert_raises(ArgumentError) { RollbackRelease.validate_version('') }
  end

  def test_prep_branch_name
    assert_equal 'chore/release-1.6.1', RollbackRelease.prep_branch_name('1.6.1')
  end

  def test_rollback_branch_name
    assert_equal 'chore/rollback-1.6.1', RollbackRelease.rollback_branch_name('1.6.1')
  end

  def test_prep_commit_subject
    assert_equal 'Prepare release 1.6.1', RollbackRelease.prep_commit_subject('1.6.1')
  end

  # --- helpers to stub subprocess wrappers -----------------------------------

  def with_recorded_run
    calls = []
    recorder = lambda do |cmd, cwd: nil, check: true|
      calls << [cmd, cwd, check]
      nil
    end
    RollbackRelease.stub(:run, recorder) do
      yield calls
    end
  end

  def with_capture_returning(output_by_cmd_prefix)
    faker = lambda do |cmd, cwd: nil|
      key = output_by_cmd_prefix.keys.find { |prefix| cmd.take(prefix.length) == prefix }
      raise "Unmocked capture call: #{cmd.inspect}" unless key

      output_by_cmd_prefix[key]
    end
    RollbackRelease.stub(:capture, faker) do
      yield
    end
  end

  # --- workflow-run discovery + cancel ---------------------------------------

  def test_discover_pending_run_returns_first_active_run_id
    payload = JSON.generate(
      [
        { 'databaseId' => 111, 'status' => 'completed' },
        { 'databaseId' => 222, 'status' => 'waiting' },
        { 'databaseId' => 333, 'status' => 'in_progress' }
      ]
    )
    with_capture_returning(%w[gh run list] => payload) do
      assert_equal '222', RollbackRelease.discover_pending_run(cwd: REPO)
    end
  end

  def test_discover_pending_run_returns_nil_when_none_active
    payload = JSON.generate(
      [
        { 'databaseId' => 111, 'status' => 'completed' },
        { 'databaseId' => 112, 'status' => 'completed' }
      ]
    )
    with_capture_returning(%w[gh run list] => payload) do
      assert_nil RollbackRelease.discover_pending_run(cwd: REPO)
    end
  end

  def test_cancel_run_invokes_gh_run_cancel_with_check_false
    with_recorded_run do |calls|
      RollbackRelease.cancel_run(999, cwd: REPO)
      assert_equal 1, calls.length
      assert_equal ['gh', 'run', 'cancel', '999'], calls[0][0]
      assert_equal REPO, calls[0][1]
      refute calls[0][2], 'cancel_run must pass check: false'
    end
  end

  # --- commit discovery + revert ---------------------------------------------

  def test_find_prep_commit_matches_exact_subject
    log = <<~OUT
      cafebabe0 Some other commit
      deadbeef1 Prepare release 1.6.1
      abc12300 Prepare release 1.6.0
    OUT
    with_capture_returning(%w[git log origin/main] => log) do
      assert_equal 'deadbeef1', RollbackRelease.find_prep_commit('1.6.1', cwd: REPO)
    end
  end

  def test_find_prep_commit_returns_nil_when_missing
    with_capture_returning(%w[git log origin/main] => "cafebabe0 Some other commit\n") do
      assert_nil RollbackRelease.find_prep_commit('1.6.1', cwd: REPO)
    end
  end

  def test_parent_count_from_rev_list_output
    # 1 parent (normal commit): line has 2 hashes total
    with_capture_returning(%w[git rev-list --parents] => "deadbeef1 cafebabe0\n") do
      assert_equal 1, RollbackRelease.parent_count('deadbeef1', cwd: REPO)
    end
    # 2 parents (merge commit): line has 3 hashes total
    with_capture_returning(%w[git rev-list --parents] => "deadbeef1 cafebabe0 abc12300\n") do
      assert_equal 2, RollbackRelease.parent_count('deadbeef1', cwd: REPO)
    end
  end

  def test_revert_prep_commit_squash_merge_no_dash_m
    # 1 parent → not a merge → no -m 1
    with_capture_returning(%w[git rev-list --parents] => "deadbeef1 cafebabe0\n") do
      with_recorded_run do |calls|
        RollbackRelease.revert_prep_commit('deadbeef1', cwd: REPO)
        assert_equal 1, calls.length
        assert_equal(['git', 'revert', '--no-edit', 'deadbeef1'], calls[0][0])
      end
    end
  end

  def test_revert_prep_commit_true_merge_uses_dash_m_1
    # 2 parents → merge commit → needs -m 1
    with_capture_returning(%w[git rev-list --parents] => "deadbeef1 cafebabe0 abc12300\n") do
      with_recorded_run do |calls|
        RollbackRelease.revert_prep_commit('deadbeef1', cwd: REPO)
        assert_equal(['git', 'revert', '--no-edit', '-m', '1', 'deadbeef1'], calls[0][0])
      end
    end
  end

  # --- git / gh side effects -------------------------------------------------

  def test_create_rollback_branch_fetches_and_switches
    with_recorded_run do |calls|
      RollbackRelease.create_rollback_branch('1.6.1', cwd: REPO)
      assert_equal(
        [
          [%w[git fetch origin main], REPO, true],
          [['git', 'switch', '--create', 'chore/rollback-1.6.1', 'origin/main'], REPO, true]
        ],
        calls
      )
    end
  end

  def test_push_rollback_branch
    with_recorded_run do |calls|
      RollbackRelease.push_rollback_branch('1.6.1', cwd: REPO)
      assert_equal(
        [[['git', 'push', '--set-upstream', 'origin', 'chore/rollback-1.6.1'], REPO, true]],
        calls
      )
    end
  end

  def test_create_rollback_pr_uses_versioned_branch
    with_recorded_run do |calls|
      RollbackRelease.create_rollback_pr('1.6.1', cwd: REPO)
      assert_equal 1, calls.length
      cmd = calls[0][0]
      assert_equal 'gh', cmd[0]
      assert_equal 'pr', cmd[1]
      assert_equal 'create', cmd[2]
      assert_includes cmd, 'main'
      assert_includes cmd, 'chore/rollback-1.6.1'
      assert_includes cmd, 'Revert release 1.6.1'
    end
  end
end
