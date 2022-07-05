require 'bundler/gem_tasks'
require 'rbs_protobuf'
require 'fileutils'

PROTO_ROOT = 'bridge/sdk-core/protos/api_upstream'.freeze
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

namespace :proto do
  desc 'Generate API protobufs'
  task :generate do
    FileUtils.mkdir_p(PROTOBUF_PATH)
    FileUtils.mkdir_p(RBS_SIG_PATH)
    FileUtils.mkdir_p(GRPC_PATH)

    Dir.glob("#{PROTO_ROOT}/**/*.proto").map { |f| File.dirname(f) }.uniq.sort.each do |dir|
      sh 'RBS_PROTOBUF_BACKEND=protobuf RBS_PROTOBUF_EXTENSION=true ' \
         'bundle exec grpc_tools_ruby_protoc ' \
         "--proto_path=#{PROTO_ROOT} " \
         "--ruby_out=#{PROTOBUF_PATH} " \
         "--grpc_out=#{GRPC_PATH} " \
         "--rbs_out=#{RBS_SIG_PATH} #{dir}/*.proto"
    end
  end
end
