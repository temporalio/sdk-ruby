# frozen_string_literal: true

raise 'Must provide gem file glob' if ARGV.length != 1

gem_files = Dir.glob(ARGV.first)
raise "Unable to find single gem file, found #{gem_files.length}" unless gem_files.length == 1

# TODO(cretz): For Linux musl, we have to install google-protobuf manually because latest versions do not work with
# musl. Remove this when https://github.com/protocolbuffers/protobuf/issues/16853 is resolved.
if RUBY_PLATFORM.include?('linux-musl')
  system('gem', 'install', '--verbose', 'google-protobuf', '--platform', 'ruby', exception: true)
end

system('gem', 'install', '--verbose', gem_files.first, exception: true)

# Create a local environment and start a workflow
require 'temporalio/client'
require 'temporalio/testing/workflow_environment'

Temporalio::Testing::WorkflowEnvironment.start_local do |env|
  handle = env.client.start_workflow('MyWorkflow', id: 'my-workflow', task_queue: 'my-task-queue')
  puts "Successfully created workflow with run ID: #{handle.result_run_id}"
end
