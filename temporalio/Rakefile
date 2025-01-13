# frozen_string_literal: true

# rubocop:disable Lint/MissingCopEnableDirective, Style/DocumentationMethod

require 'bundler/gem_tasks'
require 'rb_sys/cargo/metadata'
require 'rb_sys/extensiontask'

task build: :compile

GEMSPEC = Gem::Specification.load('temporalio.gemspec')

begin
  RbSys::ExtensionTask.new('temporalio_bridge', GEMSPEC) do |ext|
    ext.lib_dir = 'lib/temporalio/internal/bridge'
  end
rescue RbSys::CargoMetadataError
  raise 'Source gem cannot be installed directly, must be a supported platform'
end

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.warning = false
  t.libs << 'test'
  t.libs << 'lib'
  t.test_files = FileList['test/**/*_test.rb']
end

def add_protoc_to_path
  tools_spec = Gem::Specification.find_by_name('grpc-tools')
  cpu = RbConfig::CONFIG['host_cpu']
  cpu = 'x86_64' if cpu == 'x64'
  os = RbConfig::CONFIG['host_os']
  os = 'windows' if os.start_with?('mingw')
  protoc_path = "#{tools_spec.gem_dir}/bin/#{cpu}-#{os}"
  separator = os == 'windows' ? ';' : ':'
  ENV['PATH'] = "#{ENV.fetch('PATH', nil)}#{separator}#{protoc_path}"
end

add_protoc_to_path

require 'rubocop/rake_task'

RuboCop::RakeTask.new

require 'steep/rake_task'

Steep::RakeTask.new

require 'yard'

module CustomizeYardWarnings # rubocop:disable Style/Documentation
  def process
    super
  rescue YARD::Parser::UndocumentableError
    # We ignore if it's an API warning
    last_file = statement.last.file
    raise unless (last_file.start_with?('lib/temporalio/api/') && last_file.count('/') > 3) ||
                 last_file.start_with?('lib/temporalio/internal/bridge/api/')
  end
end

YARD::Handlers::Ruby::ConstantHandler.prepend(CustomizeYardWarnings)

YARD::Rake::YardocTask.new { |t| t.options = ['--fail-on-warning'] }

Rake::Task[:yard].enhance([:copy_parent_files]) do
  rm ['LICENSE', 'README.md']
end

namespace :proto do
  desc 'Generate API and Core protobufs'
  task :generate do
    require_relative 'extra/proto_gen'
    ProtoGen.new.run
  end
end

namespace :rbs do
  desc 'RBS tasks'
  task :install_collection do
    sh 'rbs collection install'
  end
end

# We have to copy some parent files to this dir for gem
task :copy_parent_files do
  cp '../LICENSE', 'LICENSE'
  cp '../README.md', 'README.md'
end
Rake::Task[:build].enhance([:copy_parent_files]) do
  rm ['LICENSE', 'README.md']
end

task :rust_lint do
  sh 'cargo', 'clippy', '--', '-Dwarnings'
  sh 'cargo', 'fmt', '--check'
end

task default: ['rubocop', 'yard', 'rbs:install_collection', 'steep', 'rust_lint', 'compile', 'test']
