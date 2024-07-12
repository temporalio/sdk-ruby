# frozen_string_literal: true

require 'minitest/autorun'
require 'singleton'

module TestHelper
  def env
    TestEnvironment.instance
  end

  class TestEnvironment
    include Singleton

    attr_reader :server

    def initialize
      @server = Temporalio::Testing::WorkflowEnvironment.start_local
      Minitest.after_run do
        @server.shutdown
      end
    end

    def client
      @server.client
    end

    def with_kitchen_sink_worker(worker_client = client)
      # Run the golangworker
      task_queue = "tq-#{SecureRandom.uuid}"
      pid = Process.spawn(
        kitchen_sink_exe,
        worker_client.connection.target_host, worker_client.namespace, task_queue,
        { chdir: File.join(__dir__ || '', 'golangworker') }
      )
      begin
        yield task_queue
      ensure
        Process.kill('KILL', pid)
        Timeout.timeout(5) { Process.wait(pid) }
      end
    end

    def kitchen_sink_exe
      @kitchen_sink_mutex ||= Mutex.new
      @kitchen_sink_mutex.synchronize do
        return @kitchen_sink_exe if @kitchen_sink_exe

        # Build the executable. We can't use "go run" because it can't forward kill
        # signal
        pid = Process.spawn(
          'go', 'build', '-o', 'golangworker', '.',
          { chdir: File.join(__dir__ || '', 'golangworker') }
        )
        begin
          Timeout.timeout(100) { Process.wait(pid) }
        rescue StandardError
          Process.kill('KILL', pid)
          raise
        end
        raise "Go build failed with #{$?.exitstatus}" unless $?.exitstatus.zero? # rubocop:disable Style/SpecialGlobalVars

        @kitchen_sink_exe = File.join(__dir__ || '', 'golangworker', 'golangworker')
      end
    end
  end
end
