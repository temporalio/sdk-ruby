# frozen_string_literal: true

# rubocop:disable Style/Documentation, Style/DocumentationMethod

require_relative '../lib/temporalio/activity'
require_relative '../lib/temporalio/client'
require_relative '../lib/temporalio/testing'
require_relative '../lib/temporalio/worker'
require_relative '../lib/temporalio/workflow'

require 'async'
require 'async/barrier'
require 'logger'
require 'optparse'
require 'securerandom'

module SimpleBench
  class BenchActivity < Temporalio::Activity::Definition
    def execute(name)
      "Hello, #{name}!"
    end
  end

  class BenchWorkflow < Temporalio::Workflow::Definition
    def execute(name)
      Temporalio::Workflow.execute_activity(BenchActivity, name, start_to_close_timeout: 30)
    end
  end
end

def run_bench(workflow_count:, max_cached_workflows:, max_concurrent:)
  logger = Logger.new($stdout)

  # Track mem
  stop_track_mem = false
  track_mem_task = Async do
    max_mem_mib = 0
    until stop_track_mem
      sleep(0.8)
      curr_mem = `ps -o rss= -p #{Process.pid}`.to_i / 1024
      max_mem_mib = curr_mem if curr_mem > max_mem_mib
    end
    max_mem_mib
  end

  logger.info('Starting local environment')
  Temporalio::Testing::WorkflowEnvironment.start_local(logger:) do |env|
    task_queue = "tq-#{SecureRandom.uuid}"

    # Create a bunch of workflows
    logger.info("Starting #{workflow_count} workflows")
    start_begin = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    handle_tasks = workflow_count.times.map do |i|
      Async do
        env.client.start_workflow(SimpleBench::BenchWorkflow, "user-#{i}", id: "wf-#{SecureRandom.uuid}", task_queue:)
      end
    end
    handles = handle_tasks.map(&:wait)
    start_seconds = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_begin).round(3)

    # Start a worker to run them all
    logger.info('Starting worker')
    result_seconds = Temporalio::Worker.new(
      client: env.client,
      task_queue:,
      activities: [SimpleBench::BenchActivity],
      workflows: [SimpleBench::BenchWorkflow],
      tuner: Temporalio::Worker::Tuner.create_fixed(
        workflow_slots: max_concurrent,
        activity_slots: max_concurrent,
        local_activity_slots: max_concurrent
      ),
      max_cached_workflows:
    ).run do
      # Wait for all workflows
      result_begin = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      handles.map(&:result)
      (Process.clock_gettime(Process::CLOCK_MONOTONIC) - result_begin).round(3)
    end

    # Report results
    stop_track_mem = true
    puts 'Results:', {
      workflow_count:,
      max_cached_workflows:,
      max_concurrent:,
      max_mem_mib: track_mem_task.wait,
      start_seconds:,
      result_seconds:,
      workflows_per_second: (workflow_count / result_seconds).round(3)
    }
  end
ensure
  stop_track_mem = true
  logger.close
end

def track_mem(&)
  stop = false
  thread = Thread.new do
    max_mem = 0
    until stop
      sleep(0.8)
      curr_mem = `ps -o rss= -p #{Process.pid}`.to_i
      max_mem = curr_mem if curr_mem > max_mem
    end
    max_mem
  end
  yield
  stop = true
  thread.value
ensure
  stop = true
end

# Parse options
parser = OptionParser.new
workflow_count = 0
max_cached_workflows = 0
max_concurrent = 0
parser.on('--workflow-count WORKFLOW_COUNT') { |v| workflow_count = v.to_i }
parser.on('--max-cached-workflows MAX_CACHED_WORKFLOWS') { |v| max_cached_workflows = v.to_i }
parser.on('--max-concurrent MAX_CONCURRENT') { |v| max_concurrent = v.to_i }
parser.parse!
if workflow_count.zero? || max_cached_workflows.zero? || max_concurrent.zero?
  puts parser
  raise 'Missing one or more arguments'
end

# Run
Sync { run_bench(workflow_count:, max_cached_workflows:, max_concurrent:) }

# rubocop:enable Style/Documentation, Style/DocumentationMethod
