require 'bundler/gem_tasks'
require 'rbs_protobuf'
require 'fileutils'

API_PROTO_ROOT = 'bridge/sdk-core/protos/api_upstream'.freeze
CORE_PROTO_ROOT = 'bridge/sdk-core/protos/local'.freeze
PROTOBUF_PATH = 'lib/gen'.freeze
RBS_SIG_PATH = 'sig/protos'.freeze
GRPC_PATH = 'spec/support/grpc'.freeze

namespace :bridge do
  desc 'Build SDK Core Bridge'
  task :build do
    sh 'cd bridge && cargo build'
  end

  desc 'Release SDK Core Bridge'
  task :release do
    sh 'cd bridge && cargo build --release'
  end

  # Mac OS with rbenv users keep leaving behind build artifacts from
  #   when they tried to build against a statically linked Ruby and then
  #   try against a dynamically linked one causing errors in the build result
  desc 'Clean up previous build artefacts'
  task :clean do
    sh 'cd bridge && cargo clean'
  end
end

namespace :test_server do
  desc 'Build Go server and worker'
  task :build do
    sh 'cd spec/support/go_server && go build *.go'
    sh 'cd spec/support/go_worker && go build *.go'
  end
end

namespace :proto do
  desc 'Generate API and Core protobufs'
  task :generate do
    FileUtils.mkdir_p(PROTOBUF_PATH)
    FileUtils.mkdir_p(RBS_SIG_PATH)
    FileUtils.mkdir_p(GRPC_PATH)

    api_protos = Dir.glob("#{API_PROTO_ROOT}/**/*.proto")
    core_protos = Dir.glob("#{CORE_PROTO_ROOT}/**/*.proto")
    protos = (api_protos + core_protos).uniq.sort.join(' ')

    sh 'RBS_PROTOBUF_BACKEND=protobuf RBS_PROTOBUF_EXTENSION=true ' \
       'bundle exec grpc_tools_ruby_protoc ' \
       "--proto_path=#{API_PROTO_ROOT} " \
       "--proto_path=#{CORE_PROTO_ROOT} " \
       "--ruby_out=#{PROTOBUF_PATH} " \
       "--grpc_out=#{GRPC_PATH} " \
       "--rbs_out=#{RBS_SIG_PATH} #{protos}"
  end
end
