# frozen_string_literal: true

# Release workflow validation helpers.
#
# Subcommands:
#   validate-version [--sha SHA] [--github-output PATH]
#       Read Temporalio::VERSION from temporalio/lib/temporalio/version.rb,
#       assert it looks like a semver-ish string with no leading 'v',
#       and emit `version=...` (and optional `sha=...`) to GITHUB_OUTPUT.
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
