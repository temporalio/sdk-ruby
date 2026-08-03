# frozen_string_literal: true

# Roll back an in-flight release.
#
# Given a version, this:
#   1. Cancels the specified Release Publish workflow run (auto-discovered
#      from `gh run list` if --run-id is not provided).
#   2. Finds the "Prepare release VERSION" commit on origin/main.
#   3. Creates chore/rollback-VERSION off origin/main, `git revert`s the
#      prep commit (with -m 1 if it's a merge commit), pushes, and opens
#      a revert PR via `gh`.
#
# The revert PR is reviewed and merged through the normal PR flow. Once
# merged, main is back to pre-release state and the release can be retried
# by running scripts/prepare_release.rb again.
#
# Intended use: rehearse a full release, hit the rubygems env gate, decide
# not to approve, and roll back cleanly with `ruby scripts/rollback_release.rb VERSION`.

require 'json'
require 'open3'
require 'optparse'
require 'pathname'

module RollbackRelease
  REPO_ROOT = Pathname.new(__dir__).parent.expand_path

  VERSION_RE = /\A[0-9]+(?:\.[0-9]+)+[A-Za-z0-9_.+\-]*\z/.freeze

  # Statuses that indicate a workflow run has not yet reached a terminal
  # state — the env-gate `waiting` state is the interesting one for our
  # rehearsal use case.
  ACTIVE_RUN_STATUSES = %w[in_progress queued waiting requested pending].freeze

  module_function

  def validate_version(version)
    raise ArgumentError, "Invalid version #{version.inspect}; expected '1.30.0'-style" unless VERSION_RE.match?(version)

    version
  end

  def prep_branch_name(version)
    "chore/release-#{version}"
  end

  def rollback_branch_name(version)
    "chore/rollback-#{version}"
  end

  def prep_commit_subject(version)
    "Prepare release #{version}"
  end

  # --- subprocess wrappers (stubbed in tests) --------------------------------

  def run(cmd, cwd: REPO_ROOT, check: true)
    system(*cmd, chdir: cwd.to_s, exception: check)
  end

  def capture(cmd, cwd: REPO_ROOT)
    stdout, status = Open3.capture2(*cmd, chdir: cwd.to_s)
    raise "Command failed (#{status.exitstatus}): #{cmd.join(' ')}" unless status.success?

    stdout
  end

  # --- workflow-run discovery + cancel ---------------------------------------

  # Return the databaseId of the most recent non-terminal Release Publish
  # run on `main`, or nil if none is pending.
  def discover_pending_run(cwd: REPO_ROOT)
    output = capture(
      [
        'gh', 'run', 'list',
        '--workflow', 'release-publish.yml',
        '--branch', 'main',
        '--limit', '10',
        '--json', 'databaseId,status'
      ],
      cwd: cwd
    )
    JSON.parse(output).each do |entry|
      return entry['databaseId'].to_s if ACTIVE_RUN_STATUSES.include?(entry['status'])
    end
    nil
  end

  def cancel_run(run_id, cwd: REPO_ROOT)
    # `check: false` — if the run has already ended between discovery and
    # this call, `gh run cancel` will complain; that's fine.
    run(['gh', 'run', 'cancel', run_id.to_s], cwd: cwd, check: false)
  end

  # --- commit discovery + revert ---------------------------------------------

  # SHA on origin/main whose subject equals "Prepare release VERSION",
  # or nil if not found in the recent history.
  def find_prep_commit(version, cwd: REPO_ROOT)
    subject = prep_commit_subject(version)
    output = capture(['git', 'log', 'origin/main', '--format=%H %s', '-50'], cwd: cwd)
    output.each_line do |line|
      sha, _, msg = line.chomp.partition(' ')
      return sha if msg == subject
    end
    nil
  end

  # Number of parents of the given commit. 1 = normal / squash-merged,
  # 2+ = merge commit (needs `-m 1` on revert).
  def parent_count(sha, cwd: REPO_ROOT)
    output = capture(['git', 'rev-list', '--parents', '-n', '1', sha], cwd: cwd)
    output.chomp.split.length - 1
  end

  # --- git / gh side effects -------------------------------------------------

  def create_rollback_branch(version, cwd: REPO_ROOT)
    run(%w[git fetch origin main], cwd: cwd)
    run(['git', 'switch', '--create', rollback_branch_name(version), 'origin/main'], cwd: cwd)
  end

  def revert_prep_commit(sha, cwd: REPO_ROOT)
    args = ['git', 'revert', '--no-edit']
    args += ['-m', '1'] if parent_count(sha, cwd: cwd) >= 2
    args << sha
    run(args, cwd: cwd)
  end

  def push_rollback_branch(version, cwd: REPO_ROOT)
    run(['git', 'push', '--set-upstream', 'origin', rollback_branch_name(version)], cwd: cwd)
  end

  def create_rollback_pr(version, cwd: REPO_ROOT)
    run(
      [
        'gh', 'pr', 'create',
        '--base', 'main',
        '--head', rollback_branch_name(version),
        '--title', "Revert release #{version}",
        '--body', "Reverts \"Prepare release #{version}\". Release rehearsal aborted before publish."
      ],
      cwd: cwd
    )
  end

  # --- main ------------------------------------------------------------------

  def main(argv)
    options = { run_id: nil, skip_cancel: false, skip_revert: false, dry_run: false }
    parser = OptionParser.new do |o|
      o.banner = 'Usage: rollback_release.rb VERSION [options]'
      o.on('--run-id ID',   'Specific workflow run to cancel (default: auto-discover pending run)') { |v| options[:run_id] = v }
      o.on('--skip-cancel', 'Do not cancel any workflow runs')                                       { options[:skip_cancel] = true }
      o.on('--skip-revert', 'Do not revert the prep commit or open a PR')                            { options[:skip_revert] = true }
      o.on('--dry-run',     'Print planned actions; make no changes')                                { options[:dry_run] = true }
    end
    positional = parser.parse(argv)
    if positional.length != 1
      warn parser.help
      exit 2
    end

    version = validate_version(positional.first)

    unless options[:skip_cancel]
      run_id = options[:run_id] || discover_pending_run
      if run_id
        puts "Cancelling workflow run #{run_id}"
        cancel_run(run_id) unless options[:dry_run]
      else
        puts 'No pending Release Publish run found; nothing to cancel'
      end
    end

    return if options[:skip_revert]

    run(%w[git fetch origin main]) unless options[:dry_run]
    sha = find_prep_commit(version)
    unless sha
      warn "No \"#{prep_commit_subject(version)}\" commit found on origin/main."
      warn 'If the prep PR was never merged, close it and delete the branch manually.'
      exit 1
    end

    puts "Reverting #{sha[0, 8]} (\"#{prep_commit_subject(version)}\")"
    if options[:dry_run]
      puts "  would create branch: #{rollback_branch_name(version)}"
      puts '  would run: git revert' + (parent_count(sha) >= 2 ? ' -m 1 ' : ' ') + sha
      puts '  would push branch and open a "Revert release" PR'
      return
    end

    create_rollback_branch(version)
    revert_prep_commit(sha)
    push_rollback_branch(version)
    create_rollback_pr(version)
    puts "Rollback PR opened. Review and merge it to restore main."
  end
end

RollbackRelease.main(ARGV) if $PROGRAM_NAME == __FILE__
