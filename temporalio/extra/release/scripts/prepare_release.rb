# frozen_string_literal: true

# rubocop:disable Style/Documentation, Style/DocumentationMethod

# Prepare checked-in files for a Ruby SDK release.
#
# Bumps Temporalio::VERSION, refreshes Gemfile.lock, assembles changelog fragments
# through Core's shared tool, and — unless --skip-git is passed — creates a
# chore/release-VERSION branch off origin/main, commits the release files,
# pushes, and opens the release PR via `gh`.

require 'date'
require 'optparse'
require 'pathname'

require_relative 'changelog'

module PrepareRelease
  REPO_ROOT = Pathname.new(__dir__).parent.parent.parent.parent.expand_path

  VERSION_RE = /\A[0-9]+(?:\.[0-9]+)+[A-Za-z0-9_.+-]*\z/
  RELEASE_FILES = [
    'CHANGELOG.md',
    'temporalio/Gemfile.lock',
    'temporalio/lib/temporalio/version.rb'
  ].freeze

  module_function

  def validate_version(version)
    raise ArgumentError, "Invalid version #{version.inspect}; expected '1.30.0'-style" unless VERSION_RE.match?(version)

    version
  end

  def parse_date(str)
    Date.iso8601(str)
  rescue ArgumentError
    raise ArgumentError, "Invalid release date #{str.inspect}; expected YYYY-MM-DD"
  end

  # Replace `VERSION = '...'` in lib/temporalio/version.rb. Preserves the
  # quote style already in the file.
  def replace_version_constant(text, version)
    validate_version(version)
    updated = text.sub(/^(\s*VERSION\s*=\s*)(['"])[^'"]+\2/) do
      "#{Regexp.last_match(1)}#{Regexp.last_match(2)}#{version}#{Regexp.last_match(2)}"
    end
    raise 'Could not find VERSION constant' if updated == text

    updated
  end

  # --- git / gh side effects -------------------------------------------------

  def run(cmd, cwd: REPO_ROOT, check: true)
    system(*cmd, chdir: cwd.to_s, exception: check)
  end

  def capture(cmd, cwd: REPO_ROOT)
    require 'open3'
    stdout, status = Open3.capture2(*cmd, chdir: cwd.to_s)
    raise "Command failed (#{status.exitstatus}): #{cmd.join(' ')}" unless status.success?

    stdout
  end

  def changed_files(cwd: REPO_ROOT)
    capture(%w[git status --porcelain], cwd: cwd).lines(chomp: true).to_set { |line| line[3..] }
  end

  def ensure_clean_worktree(cwd: REPO_ROOT)
    changes = changed_files(cwd: cwd)
    return if changes.empty?

    raise "Release preparation requires a clean worktree; found changes in #{changes.to_a.sort.join(', ')}"
  end

  def ensure_only_release_changes(cwd: REPO_ROOT, consumed_paths: [])
    unexpected = changed_files(cwd: cwd) - RELEASE_FILES - consumed_paths
    return if unexpected.empty?

    raise "Release preparation changed unexpected files: #{unexpected.to_a.sort.join(', ')}"
  end

  def branch_name(version)
    "chore/release-#{version}"
  end

  def create_release_branch(version, base_ref: 'origin/main', cwd: REPO_ROOT)
    branch = base_ref.sub(%r{\Aorigin/}, '')
    raise "base_ref must be an 'origin/...' ref, got #{base_ref.inspect}" if branch == base_ref

    run(['git', 'fetch', 'origin', branch], cwd: cwd)
    run(['git', 'switch', '--create', branch_name(version), base_ref], cwd: cwd)
    run(%w[git submodule update --init --recursive], cwd: cwd)
  end

  def commit_release_changes(version, cwd: REPO_ROOT, consumed_paths: [])
    run(['git', 'commit', '-m', "Prepare release #{version}", '--', *RELEASE_FILES, *consumed_paths], cwd: cwd)
  end

  def push_release_branch(version, cwd: REPO_ROOT)
    run(['git', 'push', '--set-upstream', 'origin', branch_name(version)], cwd: cwd)
  end

  def create_release_pr(version, cwd: REPO_ROOT)
    run(
      ['gh', 'pr', 'create',
       '--base', 'main',
       '--head', branch_name(version),
       '--title', "Prepare release #{version}",
       '--body', "Prepare release #{version}.",
       '--label', 'skip-changelog'], # Make CI allow the changes
      cwd: cwd
    )
  end

  # --- main ------------------------------------------------------------------

  def prepare_release_files(version, release_date, cwd: REPO_ROOT, skip_lock: false)
    version_path = cwd.join('temporalio/lib/temporalio/version.rb')
    version_path.write(replace_version_constant(version_path.read, version))
    run(%w[bundle lock], cwd: cwd.join('temporalio')) unless skip_lock
    Changelog.run('prepare', '--version', version, '--date', release_date.iso8601, repo_root: cwd)
    capture(%w[git ls-files --deleted -z -- changelog], cwd: cwd).split("\0")
  end

  def main(argv)
    options = {
      date: Date.today.iso8601,
      skip_lock: false,
      skip_git: false,
      base_ref: 'origin/main'
    }
    parser = OptionParser.new do |o|
      o.banner = 'Usage: prepare_release.rb VERSION [options]'
      o.on('--date DATE', 'Release date in YYYY-MM-DD (default: today)') do |v|
        options[:date] = v
      end
      o.on('--base-ref REF', 'Git ref to branch the release from (default: origin/main)') do |v|
        options[:base_ref] = v
      end
      o.on('--skip-lock', 'Skip refreshing Gemfile.lock (local testing only)') do
        options[:skip_lock] = true
      end
      o.on('--skip-git', 'Skip branch/commit/push/PR (local testing only)') do
        options[:skip_git] = true
      end
    end
    positional = parser.parse(argv)
    if positional.length != 1
      warn parser.help
      exit 2
    end

    version = validate_version(positional.first)
    release_date = parse_date(options[:date])

    ensure_clean_worktree unless options[:skip_git]
    create_release_branch(version, base_ref: options[:base_ref]) unless options[:skip_git]

    consumed = prepare_release_files(version, release_date, skip_lock: options[:skip_lock])

    unless options[:skip_git]
      ensure_only_release_changes(consumed_paths: consumed)
      commit_release_changes(version, consumed_paths: consumed)
      push_release_branch(version)
      create_release_pr(version)
    end

    puts "Prepared release #{version} dated #{release_date.iso8601}#{' and opened a PR' unless options[:skip_git]}"
  end
end

PrepareRelease.main(ARGV) if $PROGRAM_NAME == __FILE__

# rubocop:enable Style/Documentation, Style/DocumentationMethod
