require 'bundler/gem_tasks'
require 'rbs_protobuf'
require 'fileutils'
require 'thermite/tasks'
require_relative 'lib/thermite_patch'

API_PROTO_ROOT = 'bridge/sdk-core/protos/api_upstream'.freeze
CORE_PROTO_ROOT = 'bridge/sdk-core/protos/local'.freeze
TEST_PROTO_ROOT = 'bridge/sdk-core/protos/testsrv_upstream'.freeze
PROTOBUF_PATH = 'lib/gen'.freeze
RBS_SIG_PATH = 'sig/protos'.freeze
GRPC_PATH = 'spec/support/grpc'.freeze

Thermite::Tasks.new(
  cargo_project_path: File.expand_path('bridge', __dir__),
  ruby_project_path: __dir__,
)

namespace :bridge do
  desc 'Run a linter on SDK Core Bridge'
  task :lint do
    sh 'cd bridge && cargo clippy --workspace --all-features --all-targets -- -D warnings'
  end

  desc 'Build SDK Core Bridge'
  task :build do
    ENV['CARGO_PROFILE'] = 'debug'
    Rake::Task['thermite:build'].invoke
  end

  desc 'Release SDK Core Bridge'
  task release: ['thermite:build']

  # Mac OS with rbenv users keep leaving behind build artifacts from
  #   when they tried to build against a statically linked Ruby and then
  #   try against a dynamically linked one causing errors in the build result
  desc 'Clean up previous build artefacts'
  task clean: ['thermite:clean']
end

namespace :test_server do
  desc 'Build Go server and worker'
  task :build do
    sh 'cd spec/support/go_server && go build *.go'
    sh 'cd spec/support/go_worker && go build *.go'
  end
end

# rubocop:disable Metrics/BlockLength
namespace :proto do
  desc 'Generate API and Core protobufs'
  task :generate do
    FileUtils.mkdir_p(PROTOBUF_PATH)
    FileUtils.mkdir_p(RBS_SIG_PATH)
    FileUtils.mkdir_p(GRPC_PATH)

    api_protos = Dir.glob("#{API_PROTO_ROOT}/**/*.proto")
    core_protos = Dir.glob("#{CORE_PROTO_ROOT}/**/*.proto")
    test_protos = Dir.glob("#{TEST_PROTO_ROOT}/**/*.proto")

    # Some files exist in more than one directories. Get rid of duplicates.
    protos = (api_protos + core_protos + test_protos).uniq do |path|
      path
        .delete_prefix(API_PROTO_ROOT)
        .delete_prefix(CORE_PROTO_ROOT)
        .delete_prefix(TEST_PROTO_ROOT)
    end.sort

    sh 'bundle exec grpc_tools_ruby_protoc ' \
       "--proto_path=#{API_PROTO_ROOT} " \
       "--proto_path=#{CORE_PROTO_ROOT} " \
       "--proto_path=#{TEST_PROTO_ROOT} " \
       "--ruby_out=#{PROTOBUF_PATH} " \
       "--grpc_out=#{GRPC_PATH} " \
       "#{protos.join(' ')}"

    # protobuf_rbs doesn't honour the ruby_package directive, which means that .rbs files modules
    # would not match modules in .rb files. For now, we work around that by rewriting package
    # directives in our input proto files.

    # Collect package names and determine the corresponding Ruby package names
    package_map = {}
    protos.each do |path|
      content = File.read(path)

      original_package = content.match(/^\s*package\s+([^;]+)\s*;/).match(1)
      ruby_package = content.match(/^\s*option\s+ruby_package\s*=\s*"([^"]+)"\s*;/)&.match(1)

      if ruby_package
        normalized_package = ruby_package.gsub(/::/, '.').gsub(/(?<=[a-zA-Z])([A-Z])/, '_\1').downcase
        package_map[original_package] = normalized_package
      else
        package_map[original_package] = original_package
      end
    end

    # Copy and fix all proto files to a temporary directory
    protos.each do |path| # rubocop:disable Style/CombinableLoops
      content = File.read(path)

      original_package = content.match(/^\s*package\s+([^;]+)\s*;/).match(1)
      normalized_package = package_map[original_package]

      # Rewrite the package directive
      content = content.gsub(/^\s*package\s+([^;]+)\s*;/, "package #{normalized_package};")

      # Fix references to renamed packages
      content = content.gsub(/(?<![.a-z])(temporal\.api\.[a-z0-9.]+)\.([a-z0-9]+)/i) do
        package = Regexp.last_match(1)
        element_name = Regexp.last_match(2)
        "#{package_map[package]}.#{element_name}"
      end

      # Write out the file for processing
      FileUtils.mkdir_p(File.dirname("tmp/#{path}"))
      File.write("tmp/#{path}", content)
    end

    sh 'RBS_PROTOBUF_BACKEND=protobuf RBS_PROTOBUF_EXTENSION=true' \
       'bundle exec grpc_tools_ruby_protoc ' \
       "--proto_path=tmp/#{API_PROTO_ROOT} " \
       "--proto_path=tmp/#{CORE_PROTO_ROOT} " \
       "--proto_path=tmp/#{TEST_PROTO_ROOT} " \
       "--rbs_out=#{RBS_SIG_PATH} " \
       "#{protos.map { |x| "tmp/#{x}" }.join(' ')}"

    # Fix generated RBS files
    rbs_files = Dir.glob("#{RBS_SIG_PATH}/**/*.rbs")
    rbs_files.each do |path|
      content = File.read(path)

      # protobuf_rbs will have created some module directive like
      # "Workflow_service". Rewrite those to proper camelcase.
      content = content.gsub(/module ([a-z0-9]+_[a-z0-9_]+)/i) do
        module_name = Regexp.last_match(1)
        camelcase_name = module_name.split('_').map(&:capitalize).join
        "module #{camelcase_name}"
      end

      # Also fix references such as Temporalio::Api::Task_queue::V1::TaskQueue
      # by rewriting them to proper camelcase.
      content = content.gsub(/Temporalio(::[a-z0-9][a-z0-9_]+)+(?=::)/i) do
        Regexp.last_match(0).split('::').map do |segment|
          if segment.match(/_/)
            segment.split('_').map(&:capitalize).join
          else
            # Some segments are already camelcase.
            # Calling capitalize on them would lowercase inner words.
            segment
          end
        end.join('::')
      end

      # Add some missing methods to the generated RBS files
      content = content.gsub(/([ \t]*)class ([a-z]+) < ::Protobuf::Message/i) do
        indent = Regexp.last_match(1)
        class_name = Regexp.last_match(2)
        original_line = Regexp.last_match(0)

        <<~EXTRA_METHODS
          #{original_line}
          #{indent}  # Encode the message to a binary string
          #{indent}  #
          #{indent}  def self.encode: (#{class_name}) -> String
        EXTRA_METHODS
      end

      File.write(path, content)
    end

    # Remove temporary files
    FileUtils.rm_rf('tmp')
  end
end
# rubocop:enable Metrics/BlockLength
