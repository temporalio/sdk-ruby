# frozen_string_literal: true

# Release workflow validation helpers.
#
# Subcommands:
#   validate-version [--sha SHA] [--github-output PATH]
#       Read Temporalio::VERSION from temporalio/lib/temporalio/version.rb,
#       assert it looks like a semver-ish string with no leading 'v',
#       and emit `version=...` (and optional `sha=...`) to GITHUB_OUTPUT.
#
#   changelog-notes --version VERSION --output PATH [--changelog PATH]
#       Extract the `## [VERSION]` section from CHANGELOG.md, prepend a
#       "Notable Changes" header, and write to PATH. Fails if the section
#       is missing or empty.
#
#   verify-dist --version VERSION --dist DIR
#       Assert DIR contains exactly the expected set of .gem files for
#       VERSION: one source gem plus one gem per platform in the release
#       matrix. Fails on duplicates, missing platforms, wrong versions,
#       or unexpected files.

require 'optparse'
require 'pathname'

REPO_ROOT = Pathname.new(__dir__).parent.parent.expand_path
VERSION_FILE = REPO_ROOT.join('temporalio', 'lib', 'temporalio', 'version.rb')
DEFAULT_CHANGELOG = REPO_ROOT.join('CHANGELOG.md')

# Platform suffixes that appear on a gem filename: temporalio-VERSION-PLATFORM.gem.
# Kept in sync with the matrix in .github/workflows/build-gems.yml.
EXPECTED_PLATFORMS = %w[
  aarch64-linux
  aarch64-linux-musl
  x86_64-linux
  x86_64-linux-musl
  arm64-darwin
  x86_64-darwin
].freeze

def checked_in_version
  source = VERSION_FILE.read
  match = source.match(/^\s*VERSION\s*=\s*['"]([^'"]+)['"]/)
  raise "Could not find VERSION constant in #{VERSION_FILE}" unless match

  version = match[1]
  raise "Checked-in version must not start with 'v': #{version.inspect}" if version.start_with?('v')
  unless version.match?(/\A[0-9]+(?:\.[0-9]+)+[A-Za-z0-9_.+\-]*\z/)
    raise "Invalid checked-in version: #{version.inspect}"
  end

  version
end

def write_github_output(path, pairs)
  File.open(path, 'a') do |file|
    pairs.each { |key, value| file.puts("#{key}=#{value}") }
  end
end

def cmd_validate_version(args)
  opts = { sha: nil, github_output: nil }
  OptionParser.new do |o|
    o.on('--sha SHA') { |v| opts[:sha] = v }
    o.on('--github-output PATH') { |v| opts[:github_output] = v }
  end.parse!(args)

  version = checked_in_version
  if opts[:github_output]
    pairs = { 'version' => version }
    pairs['sha'] = opts[:sha] if opts[:sha]
    write_github_output(opts[:github_output], pairs)
  else
    puts version
  end
end

def cmd_changelog_notes(args)
  opts = { version: nil, output: nil, changelog: DEFAULT_CHANGELOG.to_s }
  OptionParser.new do |o|
    o.on('--version VERSION') { |v| opts[:version] = v }
    o.on('--output PATH')     { |v| opts[:output] = v }
    o.on('--changelog PATH')  { |v| opts[:changelog] = v }
  end.parse!(args)

  raise '--version is required' unless opts[:version]
  raise '--output is required'  unless opts[:output]

  lines = File.readlines(opts[:changelog], chomp: true)
  heading = /\A##\s+\[(?<version>[^\]]+)\](?:\s+-\s+.*)?\s*\z/
  # sdk-ruby CHANGELOG headings use a 'v' prefix (## [v1.6.0]) even
  # though the checked-in Temporalio::VERSION does not. Match either.
  wanted = [opts[:version], "v#{opts[:version]}"]

  start_index = nil
  lines.each_with_index do |line, index|
    match = heading.match(line)
    next unless match && wanted.include?(match[:version])

    start_index = index + 1
    break
  end

  raise "Could not find changelog section for version #{opts[:version].inspect}" unless start_index

  end_index = lines.length
  (start_index...lines.length).each do |index|
    if lines[index].start_with?('## ')
      end_index = index
      break
    end
  end

  section = lines[start_index...end_index]
  section.shift while section.first && section.first.strip.empty?
  section.pop   while section.last && section.last.strip.empty?

  raise "Changelog section for #{opts[:version].inspect} is empty" if section.empty?

  File.write(opts[:output], (['## Notable Changes', ''] + section).join("\n") + "\n")
end

def cmd_verify_dist(args)
  opts = { version: nil, dist: 'dist' }
  OptionParser.new do |o|
    o.on('--version VERSION') { |v| opts[:version] = v }
    o.on('--dist DIR')        { |v| opts[:dist] = v }
  end.parse!(args)

  raise '--version is required' unless opts[:version]

  dist = Pathname.new(opts[:dist])
  raise "Dist directory does not exist: #{dist}" unless dist.directory?

  files = dist.children.select { |c| c.file? && c.extname == '.gem' }.map(&:basename).map(&:to_s).sort
  raise "Duplicate filenames in #{dist}: #{files.inspect}" if files.length != files.uniq.length

  expected_source = "temporalio-#{opts[:version]}.gem"
  expected_platform = EXPECTED_PLATFORMS.map { |p| "temporalio-#{opts[:version]}-#{p}.gem" }
  expected = ([expected_source] + expected_platform).sort

  extra   = files - expected
  missing = expected - files
  raise "Unexpected files in dist: #{extra.inspect}"       unless extra.empty?
  raise "Missing files in dist: #{missing.inspect}"        unless missing.empty?

  puts "Verified release artifacts for #{opts[:version]}:"
  files.each { |name| puts "  #{name}" }
end

DISPATCH = {
  'validate-version' => method(:cmd_validate_version),
  'changelog-notes'  => method(:cmd_changelog_notes),
  'verify-dist'      => method(:cmd_verify_dist)
}.freeze

def main(argv)
  subcommand = argv.shift
  handler = DISPATCH[subcommand]
  unless handler
    warn "Usage: #{File.basename($PROGRAM_NAME)} <#{DISPATCH.keys.join('|')}> [options]"
    exit 2
  end
  handler.call(argv)
end

main(ARGV) if $PROGRAM_NAME == __FILE__
