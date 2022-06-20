require 'bundler/gem_tasks'

namespace :bridge do
  desc 'Build SDK Core Bridge'
  task :build do
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
  PROTO_ROOT = 'bridge/sdk-core/protos/api_upstream'.freeze
  PROTO_OUT = 'lib/gen'.freeze

  desc 'Generate API protobufs'
  task :generate do
    Dir.mkdir(PROTO_OUT) unless Dir.exist?(PROTO_OUT)

    Dir.glob("#{PROTO_ROOT}/**/*.proto").map { |f| File.dirname(f) }.uniq.sort.each do |dir|
      sh "bundle exec protoc --proto_path=#{PROTO_ROOT} --ruby_out=#{PROTO_OUT} #{dir}/*.proto"
    end
  end
end
