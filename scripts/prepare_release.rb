# frozen_string_literal: true

# Prepare checked-in files for a Ruby SDK release.
#
# Bumps Temporalio::VERSION, rolls the CHANGELOG's [Unreleased] section
# into a dated [vVERSION] section (re-seeding a fresh [Unreleased]),
# refreshes Gemfile.lock, and — unless --skip-git is passed — creates a
# chore/release-VERSION branch off origin/main, commits the release files,
# pushes, and opens the release PR via `gh`.
#
# Mirrors sdk-python's scripts/prepare_release.py.

require 'date'
require 'optparse'
require 'pathname'
require 'set'

module PrepareRelease
  REPO_ROOT = Pathname.new(__dir__).parent.expand_path

  CHANGELOG_HEADERS = [
    'Added',
    'Changed',
    'Deprecated',
    ':boom: Breaking Changes',
    'Fixed',
    'Security'
  ].freeze

  VERSION_RE = /\A[0-9]+(?:\.[0-9]+)+[A-Za-z0-9_.+\-]*\z/.freeze
  CHANGELOG_HEADING_RE = /\A##\s+\[(?<version>[^\]]+)\](?:\s+-\s+.*)?\s*\z/.freeze
  CHANGELOG_SUBHEADING_RE = /\A###\s+(?<header>.+?)\s*\z/.freeze

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

  # Roll [Unreleased] into a dated [vVERSION] section, re-seed a fresh
  # empty [Unreleased] above it. Fails if [Unreleased] is empty, if a
  # section for the target version already exists, or if [Unreleased] is
  # missing entirely.
  def finalize_changelog_release(text, version:, release_date:)
    validate_version(version)
    heading = "[v#{version}]"

    lines = text.split("\n", -1)
    trailing_newline = lines.pop == '' # split with -1 keeps a trailing '' for text ending in \n

    raise "Changelog already has a section for #{heading}" if find_version_section(lines, "v#{version}")

    unreleased = find_version_section(lines, 'Unreleased')
    raise "Could not find changelog section for 'Unreleased'" unless unreleased

    heading_index, section_start, section_end = unreleased
    body = strip_empty_changelog_headers(strip_outer_blank_lines(lines[section_start...section_end]))
    raise "Changelog section for 'Unreleased' is empty" if body.empty?

    result = lines[0...heading_index] +
             seeded_unreleased_lines +
             ["## #{heading} - #{release_date.iso8601}", ''] +
             body +
             [''] +
             lines[section_end..]
    output = collapse_blank_lines(result).join("\n").rstrip
    output + (trailing_newline ? "\n" : '')
  end

  def seeded_unreleased_lines
    lines = ['## [Unreleased]', '']
    CHANGELOG_HEADERS.each { |h| lines.push("### #{h}", '') }
    lines
  end

  def find_version_section(lines, version)
    lines.each_with_index do |line, index|
      match = CHANGELOG_HEADING_RE.match(line)
      next unless match && match[:version] == version

      section_end = lines.length
      ((index + 1)...lines.length).each do |end_index|
        if lines[end_index].start_with?('## ')
          section_end = end_index
          break
        end
      end
      return [index, index + 1, section_end]
    end
    nil
  end

  def strip_outer_blank_lines(lines)
    result = lines.dup
    result.shift while result.first && result.first.strip.empty?
    result.pop   while result.last  && result.last.strip.empty?
    result
  end

  def strip_empty_changelog_headers(lines)
    filtered = []
    index = 0
    while index < lines.length
      match = CHANGELOG_SUBHEADING_RE.match(lines[index])
      unless match && CHANGELOG_HEADERS.include?(match[:header])
        filtered << lines[index]
        index += 1
        next
      end

      next_index = index + 1
      next_index += 1 while next_index < lines.length && !lines[next_index].start_with?('### ')

      body = lines[(index + 1)...next_index]
      if body.any? { |l| !l.strip.empty? }
        filtered << lines[index]
        filtered.concat(body)
      end
      index = next_index
    end
    strip_outer_blank_lines(filtered)
  end

  def collapse_blank_lines(lines)
    collapsed = []
    previous_blank = false
    lines.each do |line|
      blank = line.strip.empty?
      next if blank && previous_blank

      collapsed << line
      previous_blank = blank
    end
    collapsed
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
    capture(%w[git status --porcelain], cwd: cwd).lines(chomp: true).map { |line| line[3..] }.to_set
  end

  def ensure_clean_worktree(cwd: REPO_ROOT)
    changes = changed_files(cwd: cwd)
    return if changes.empty?

    raise "Release preparation requires a clean worktree; found changes in #{changes.to_a.sort.join(', ')}"
  end

  def ensure_only_release_changes(cwd: REPO_ROOT)
    unexpected = changed_files(cwd: cwd) - RELEASE_FILES
    return if unexpected.empty?

    raise "Release preparation changed unexpected files: #{unexpected.to_a.sort.join(', ')}"
  end

  def branch_name(version)
    "chore/release-#{version}"
  end

  def create_release_branch(version, cwd: REPO_ROOT)
    run(%w[git fetch origin main], cwd: cwd)
    run(['git', 'switch', '--create', branch_name(version), 'origin/main'], cwd: cwd)
  end

  def commit_release_changes(version, cwd: REPO_ROOT)
    run(['git', 'commit', '-m', "Prepare release #{version}", '--', *RELEASE_FILES], cwd: cwd)
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
       '--body', "Prepare release #{version}."],
      cwd: cwd
    )
  end

  # --- main ------------------------------------------------------------------

  def main(argv)
    options = { date: Date.today.iso8601, skip_lock: false, skip_git: false }
    parser = OptionParser.new do |o|
      o.banner = 'Usage: prepare_release.rb VERSION [options]'
      o.on('--date DATE', 'Release date in YYYY-MM-DD (default: today)') { |v| options[:date] = v }
      o.on('--skip-lock',  'Skip refreshing Gemfile.lock (local testing only)') { options[:skip_lock] = true }
      o.on('--skip-git',   'Skip branch/commit/push/PR (local testing only)')  { options[:skip_git] = true }
    end
    positional = parser.parse(argv)
    if positional.length != 1
      warn parser.help
      exit 2
    end

    version = validate_version(positional.first)
    release_date = parse_date(options[:date])

    ensure_clean_worktree unless options[:skip_git]
    create_release_branch(version) unless options[:skip_git]

    changelog_path = REPO_ROOT.join('CHANGELOG.md')
    version_path   = REPO_ROOT.join('temporalio', 'lib', 'temporalio', 'version.rb')

    changelog_path.write(
      finalize_changelog_release(changelog_path.read, version: version, release_date: release_date)
    )
    version_path.write(replace_version_constant(version_path.read, version))

    unless options[:skip_lock]
      run(%w[bundle lock], cwd: REPO_ROOT.join('temporalio'))
    end

    unless options[:skip_git]
      ensure_only_release_changes
      commit_release_changes(version)
      push_release_branch(version)
      create_release_pr(version)
    end

    puts "Prepared release #{version} dated #{release_date.iso8601}#{options[:skip_git] ? '' : ' and opened a PR'}"
  end
end

PrepareRelease.main(ARGV) if $PROGRAM_NAME == __FILE__
