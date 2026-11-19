# frozen_string_literal: true

# Packages a precompiled platform gem from this checkout's Ruby library and an already built bridge binary, the same
# layout as the upstream precompiled gems (the binary lives in lib/temporalio/internal/bridge/<ruby minor>/).
#
# Usage: ruby fork/package_gem.rb PLATFORM OUT_DIR RUBY_MINOR=PATH_TO_BINARY [RUBY_MINOR=PATH_TO_BINARY ...]
#   e.g. ruby fork/package_gem.rb arm64-darwin fork/dist 3.3=target/release/libtemporalio_bridge.dylib
#
# The binary is installed as temporalio_bridge.bundle on macOS and temporalio_bridge.so elsewhere. The gem requires exactly
# the Ruby minors it carries a binary for, so it fails to install on a Ruby it cannot run on instead of failing to load.
require 'fileutils'
require 'rubygems/package'
require 'tmpdir'

platform, out_dir, *binaries = ARGV
abort 'usage: package_gem.rb PLATFORM OUT_DIR MINOR=BINARY [MINOR=BINARY ...]' if platform.nil? || out_dir.nil? || binaries.empty?

# Ruby reports the macOS major version (arm64-darwin-25); published gems use plain arm64-darwin, which matches any version.
platform = platform.sub(/-darwin-\d+\z/, '-darwin')

root = File.expand_path('../temporalio', __dir__)
out_dir = File.expand_path(out_dir)
extension = platform.include?('darwin') ? 'bundle' : 'so'
minors = binaries.to_h { |pair| pair.split('=', 2).then { |minor, path| [minor, File.expand_path(path)] } }

Dir.mktmpdir('temporalio-gem') do |stage|
  %w[lib sig rbi].each { |dir| FileUtils.cp_r(File.join(root, dir), stage) }
  %w[LICENSE README.md .yardopts temporalio.gemspec].each do |file|
    source = File.join(root, file)
    FileUtils.cp(source, stage) if File.exist?(source)
  end
  minors.each do |minor, path|
    abort "missing binary: #{path}" unless File.exist?(path)
    dest = File.join(stage, 'lib', 'temporalio', 'internal', 'bridge', minor)
    FileUtils.mkdir_p(dest)
    FileUtils.cp(path, File.join(dest, "temporalio_bridge.#{extension}"))
  end

  gem_path = nil
  Dir.chdir(stage) do
    spec = Gem::Specification.load('temporalio.gemspec')
    spec.platform = Gem::Platform.new(platform)
    spec.extensions = []
    spec.files = Dir['lib/**/*', 'sig/**/*.rbs', 'rbi/**/*.rbi', 'LICENSE', 'README.md', '.yardopts'].select { |f| File.file?(f) }
    ruby_minors = minors.keys.map { |minor| Gem::Version.new(minor) }.sort
    major, minor = ruby_minors.last.segments
    spec.required_ruby_version = [">= #{ruby_minors.first}.0", "< #{major}.#{minor + 1}"]
    gem_path = Gem::Package.build(spec)
    FileUtils.mkdir_p(out_dir)
    FileUtils.mv(gem_path, out_dir)
  end
  puts File.join(out_dir, File.basename(gem_path))
end
