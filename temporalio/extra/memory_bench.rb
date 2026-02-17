# frozen_string_literal: true

# rubocop:disable Style/Documentation, Style/DocumentationMethod

# Memory profiling harness for investigating memory leaks.
# Runs trivial workflows in batches and samples RSS between batches.
#
# Usage:
#   ruby extra/memory_bench.rb --workflow-count 5000 --batch-size 500
#
# With an external Temporal server:
#   ruby extra/memory_bench.rb --workflow-count 5000 --batch-size 500 \
#     --target-host localhost:7233 --namespace default

require_relative '../lib/temporalio/activity'
require_relative '../lib/temporalio/client'
require_relative '../lib/temporalio/testing'
require_relative '../lib/temporalio/worker'
require_relative '../lib/temporalio/workflow'

require 'logger'
require 'objspace'
require 'optparse'
require 'securerandom'

module MemoryBench
  class NoopWorkflow < Temporalio::Workflow::Definition
    def execute(input)
      "done-#{input}"
    end
  end

  class SimpleActivity < Temporalio::Activity::Definition
    def execute(input)
      "activity-#{input}"
    end
  end

  class WithActivityWorkflow < Temporalio::Workflow::Definition
    def execute(input)
      Temporalio::Workflow.execute_activity(SimpleActivity, input, start_to_close_timeout: 30)
    end
  end
end

def rss_mib
  `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
end

def objspace_mib
  ObjectSpace.memsize_of_all / (1024.0 * 1024.0)
end

# Call malloc_trim(0) to return freed pages to OS (Linux only, requires fiddle gem)
MALLOC_TRIM = begin
  require 'fiddle'
  libc = Fiddle.dlopen(nil)
  Fiddle::Function.new(libc['malloc_trim'], [Fiddle::TYPE_INT], Fiddle::TYPE_INT)
rescue LoadError, Fiddle::DLError
  nil
end

def trim_native_memory
  MALLOC_TRIM&.call(0)
end

def run_memory_bench(
  workflow_count:, batch_size:, max_cached_workflows:, max_concurrent:,
  target_host:, namespace:, use_activity:
)
  logger = Logger.new($stdout, level: Logger::INFO)
  task_queue = "mem-bench-#{SecureRandom.uuid}"
  workflows = use_activity ? [MemoryBench::WithActivityWorkflow] : [MemoryBench::NoopWorkflow]
  activities = use_activity ? [MemoryBench::SimpleActivity] : []
  workflow_class = use_activity ? MemoryBench::WithActivityWorkflow : MemoryBench::NoopWorkflow

  samples = []
  samples << { workflows_completed: 0, rss_mib: rss_mib, objspace_mib: objspace_mib, phase: 'pre_connect' }

  connect_and_run = proc do |client|
    samples << { workflows_completed: 0, rss_mib: rss_mib, objspace_mib: objspace_mib, phase: 'connected' }

    worker = Temporalio::Worker.new(
      client:,
      task_queue:,
      activities:,
      workflows:,
      tuner: Temporalio::Worker::Tuner.create_fixed(
        workflow_slots: max_concurrent,
        activity_slots: max_concurrent,
        local_activity_slots: max_concurrent
      ),
      max_cached_workflows:
    )

    samples << { workflows_completed: 0, rss_mib: rss_mib, objspace_mib: objspace_mib, phase: 'worker_created' }

    # Run workflows on a separate thread while worker processes them
    completed = 0
    batches = (workflow_count.to_f / batch_size).ceil

    worker.run do
      samples << { workflows_completed: 0, rss_mib: rss_mib, objspace_mib: objspace_mib, phase: 'worker_running' }

      batches.times do |batch_idx|
        count = [batch_size, workflow_count - completed].min

        # Start and wait for each workflow sequentially
        count.times do |i|
          wf_num = completed + i
          handle = client.start_workflow(
            workflow_class, wf_num,
            id: "mem-#{SecureRandom.uuid}",
            task_queue:
          )
          handle.result
        end
        completed += count

        # Force GC, trim native allocator, and sample
        GC.start
        trim_native_memory
        mem = rss_mib
        obj = objspace_mib
        samples << { workflows_completed: completed, rss_mib: mem, objspace_mib: obj, phase: 'batch' }
        logger.info("Batch #{batch_idx + 1}/#{batches}: #{completed}/#{workflow_count} workflows, " \
                    "RSS=#{mem.round(1)} MiB, ObjSpace=#{obj.round(1)} MiB")
      end
    end

    # Post-worker sample
    GC.start
    trim_native_memory
    samples << {
      workflows_completed: workflow_count, rss_mib: rss_mib, objspace_mib: objspace_mib, phase: 'worker_stopped'
    }
  end

  # Dump dhat profile if available (compiled with dhat-heap feature)
  dhat_dump = proc do
    Temporalio::Internal::Bridge.dhat_heap_stats
    Temporalio::Internal::Bridge.dhat_dump_and_stop
  rescue NoMethodError
    # dhat not compiled in, ignore
  end

  if target_host
    logger.info("Connecting to #{target_host} namespace=#{namespace}")
    client = Temporalio::Client.connect(target_host, namespace:, logger:)
    connect_and_run.call(client)
  else
    logger.info('Starting local test environment')
    Temporalio::Testing::WorkflowEnvironment.start_local(logger:) do |env|
      connect_and_run.call(env.client)
    end
  end

  # Print results
  puts "\n=== Memory Bench Results ==="
  puts "Config: workflow_count=#{workflow_count} batch_size=#{batch_size} " \
       "max_cached_workflows=#{max_cached_workflows} max_concurrent=#{max_concurrent} " \
       "use_activity=#{use_activity}"

  batch_samples = samples.select { |s| s[:phase] == 'batch' }
  if batch_samples.size >= 2
    first = batch_samples.first
    last = batch_samples.last
    wf_delta = last[:workflows_completed] - first[:workflows_completed]
    rss_growth = last[:rss_mib] - first[:rss_mib]
    obj_growth = last[:objspace_mib] - first[:objspace_mib]
    rss_rate = wf_delta.positive? ? (rss_growth / wf_delta * 1000).round(2) : 0
    obj_rate = wf_delta.positive? ? (obj_growth / wf_delta * 1000).round(2) : 0
    puts "RSS growth:      #{rss_growth.round(2)} MiB over #{wf_delta} workflows (#{rss_rate} MiB/1000 wf)"
    puts "ObjSpace growth: #{obj_growth.round(2)} MiB over #{wf_delta} workflows (#{obj_rate} MiB/1000 wf)"
    puts "Native growth:   #{(rss_growth - obj_growth).round(2)} MiB (RSS minus ObjSpace)"
  end

  puts "\nPhase/Batch, Workflows, RSS_MiB, ObjSpace_MiB"
  samples.each do |s|
    puts "#{s[:phase]}, #{s[:workflows_completed]}, #{s[:rss_mib].round(2)}, #{s[:objspace_mib].round(2)}"
  end

  dhat_dump.call
ensure
  logger&.close
end

# Parse options
parser = OptionParser.new
workflow_count = 5000
batch_size = 500
max_cached_workflows = 1000
max_concurrent = 100
target_host = nil
namespace = 'default'
use_activity = false

parser.on('--workflow-count N', Integer, "Number of workflows (default: #{workflow_count})") { |v| workflow_count = v }
parser.on('--batch-size N', Integer, "Batch size for sampling (default: #{batch_size})") { |v| batch_size = v }
parser.on('--max-cached-workflows N', Integer,
          "Max cached workflows (default: #{max_cached_workflows})") { |v| max_cached_workflows = v }
parser.on('--max-concurrent N', Integer, "Max concurrent slots (default: #{max_concurrent})") { |v| max_concurrent = v }
parser.on('--target-host HOST', 'External Temporal host (default: start local)') { |v| target_host = v }
parser.on('--namespace NS', "Namespace (default: #{namespace})") { |v| namespace = v }
parser.on('--with-activity', 'Use workflow that calls an activity') { use_activity = true }
parser.parse!

run_memory_bench(
  workflow_count:, batch_size:, max_cached_workflows:, max_concurrent:,
  target_host:, namespace:, use_activity:
)

# rubocop:enable Style/Documentation, Style/DocumentationMethod
