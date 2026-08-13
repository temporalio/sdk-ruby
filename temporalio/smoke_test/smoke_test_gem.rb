# frozen_string_literal: true

# Smoke test for a locally-built or published temporalio gem.
#
#   ruby smoke_test_gem.rb GEM_GLOB
#     Install a local .gem file matched by the glob.
#
#   ruby smoke_test_gem.rb --version VERSION
#     Install temporalio at VERSION from rubygems.org.

require 'optparse'

options = { version: nil }
parser = OptionParser.new do |o|
  o.banner = <<~USAGE
    Usage: smoke_test_gem.rb GEM_GLOB
       or: smoke_test_gem.rb --version VERSION
  USAGE
  o.on('--version V', 'Install temporalio VERSION from rubygems.org') do |v|
    options[:version] = v
  end
end
positional = parser.parse(ARGV)

# TODO(cretz): For Linux musl, we have to install google-protobuf manually because latest versions do not work with
# musl. Remove this when https://github.com/protocolbuffers/protobuf/issues/16853 is resolved.
if RUBY_PLATFORM.include?('linux-musl')
  system('gem', 'install', '--verbose', 'google-protobuf', '--platform', 'ruby', exception: true)
end

if options[:version]
  raise 'Unexpected positional arguments in --version mode' unless positional.empty?

  system('gem', 'install', '--verbose', 'temporalio', '-v', options[:version], exception: true)
else
  raise parser.help if positional.length != 1

  gem_files = Dir.glob(positional.first)
  raise "Unable to find single gem file, found #{gem_files.length}" unless gem_files.length == 1

  system('gem', 'install', '--verbose', gem_files.first, exception: true)
end

# Create a local environment and start a workflow
require 'temporalio/client'
require 'temporalio/testing/workflow_environment'

Temporalio::Testing::WorkflowEnvironment.start_local do |env|
  handle = env.client.start_workflow('MyWorkflow', id: 'my-workflow', task_queue: 'my-task-queue')
  puts "Successfully created workflow with run ID: #{handle.result_run_id}"
end
