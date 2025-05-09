# frozen_string_literal: true

require 'async'
require 'extra_assertions'
require 'logger'
require 'minitest/autorun'
require 'securerandom'
require 'singleton'
require 'socket'
require 'temporalio/client'
require 'temporalio/converters'
require 'temporalio/internal/bridge'
require 'temporalio/runtime'
require 'temporalio/testing'
require 'timeout'
require 'workflow_utils'

# require 'memory_profiler'
# MemoryProfiler.start
# Minitest.after_run do
#   report = MemoryProfiler.stop
#   report.pretty_print
# end

class Test < Minitest::Test
  include ExtraAssertions
  include WorkflowUtils

  ATTR_KEY_TEXT = Temporalio::SearchAttributes::Key.new('ruby-key-text',
                                                        Temporalio::SearchAttributes::IndexedValueType::TEXT)
  ATTR_KEY_KEYWORD = Temporalio::SearchAttributes::Key.new('ruby-key-keyword',
                                                           Temporalio::SearchAttributes::IndexedValueType::KEYWORD)
  ATTR_KEY_INTEGER = Temporalio::SearchAttributes::Key.new('ruby-key-integer',
                                                           Temporalio::SearchAttributes::IndexedValueType::INTEGER)
  ATTR_KEY_FLOAT = Temporalio::SearchAttributes::Key.new('ruby-key-float',
                                                         Temporalio::SearchAttributes::IndexedValueType::FLOAT)
  ATTR_KEY_BOOLEAN = Temporalio::SearchAttributes::Key.new('ruby-key-boolean',
                                                           Temporalio::SearchAttributes::IndexedValueType::BOOLEAN)
  ATTR_KEY_TIME = Temporalio::SearchAttributes::Key.new('ruby-key-time',
                                                        Temporalio::SearchAttributes::IndexedValueType::TIME)
  ATTR_KEY_KEYWORD_LIST = Temporalio::SearchAttributes::Key.new(
    'ruby-key-keyword-list',
    Temporalio::SearchAttributes::IndexedValueType::KEYWORD_LIST
  )

  def self.also_run_all_tests_in_fiber
    @also_run_all_tests_in_fiber = true
    # We have to tell Minitest the diff executable to use because "async" has an
    # issue executing Kernel#system calls.
    # See https://github.com/socketry/async/issues/351
    # TODO(cretz): Remove when fixed in async
    Minitest::Assertions.diff = 'diff'
  end

  def self.method_added(method_name)
    super
    # If we are also running all tests in fiber, define `_in_fiber` equivalent,
    # unless we are < 3.3
    unless @also_run_all_tests_in_fiber &&
           method_name.start_with?('test_') &&
           !method_name.end_with?('_in_fiber') &&
           Temporalio::Internal::Bridge.fibers_supported
      return
    end

    original_method = instance_method(method_name)
    define_method("#{method_name}_in_fiber") do
      Async do |_task|
        original_method.bind(self).call
      end
    end
  end

  def skip_if_fibers_not_supported!
    return if Temporalio::Internal::Bridge.fibers_supported

    skip('Fibers not supported in this Ruby version')
  end

  def skip_if_not_x86!
    skip('Test only supported on x86') unless RbConfig::CONFIG['host_cpu'] == 'x86_64'
  end

  def env
    TestEnvironment.instance
  end

  def run_in_background(&)
    if Fiber.current_scheduler
      Fiber.schedule(&) # steep:ignore
    else
      Thread.new(&) # steep:ignore
    end
  end

  def after_teardown
    super
    return if passed? || failures.first.is_a?(Minitest::Skip)

    # Dump full cause chain on error
    puts 'Full cause chain:'
    current = failures.first&.error
    while current
      puts "Exception: #{current.class} - #{current.message}"
      puts 'Backtrace:'
      puts current.backtrace.join("\n")
      puts '-' * 50

      current = current.cause
    end
  end

  def find_free_port
    socket = TCPServer.new('127.0.0.1', 0)
    port = socket.addr[1]
    socket.close
    port
  end

  def assert_no_schedules
    assert_eventually do
      assert_empty env.client.list_schedules.to_a
    end
  end

  def delete_schedules(*ids)
    ids.each do |id|
      env.client.schedule_handle(id).delete
    end
  end

  def safe_capture_io(&)
    out, err = capture_io(&)
    out.encode!('UTF-8', invalid: :replace)
    err.encode!('UTF-8', invalid: :replace)
    [out, err]
  end

  class TestEnvironment
    include Singleton

    attr_reader :server

    def initialize
      # Start workflow env for an existing server if env vars present
      if ENV['TEMPORAL_TEST_CLIENT_TARGET_HOST']
        client = Temporalio::Client.connect(
          ENV['TEMPORAL_TEST_CLIENT_TARGET_HOST'],
          ENV['TEMPORAL_TEST_CLIENT_TARGET_NAMESPACE'] || 'default',
          logger: Logger.new($stdout)
        )
        @server = Temporalio::Testing::WorkflowEnvironment.new(client)
      else
        @server = Temporalio::Testing::WorkflowEnvironment.start_local(
          logger: Logger.new($stdout),
          dev_server_extra_args: [
            # Allow continue as new to be immediate
            '--dynamic-config-value', 'history.workflowIdReuseMinimalInterval="0s"',
            '--dynamic-config-value', 'frontend.enableVersioningWorkflowAPIs=true',
            '--dynamic-config-value', 'frontend.enableVersioningDataAPIs=true',
            '--dynamic-config-value', 'system.enableDeploymentVersions=true'
          ]
        )
        Minitest.after_run do
          @server.shutdown
        end
      end
    end

    def client
      @server.client
    end

    def with_kitchen_sink_worker(worker_client = client, task_queue: "tq-#{SecureRandom.uuid}")
      # Run the golangworker
      pid = spawn(
        kitchen_sink_exe,
        worker_client.connection.target_host, worker_client.namespace, task_queue,
        chdir: File.join(__dir__ || '', 'golangworker')
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
        pid = spawn(
          'go', 'build', '-o', 'golangworker', '.',
          chdir: File.join(__dir__ || '', 'golangworker')
        )
        begin
          Timeout.timeout(100) { Process.wait(pid) }
        rescue StandardError
          Process.kill('KILL', pid)
          raise
        end
        raise "Go build failed with #{$?&.exitstatus}" unless $?&.exitstatus&.zero? # rubocop:disable Style/SpecialGlobalVars

        @kitchen_sink_exe = File.join(__dir__ || '', 'golangworker', 'golangworker')
      end
    end

    def ensure_common_search_attribute_keys
      ensure_search_attribute_keys(ATTR_KEY_TEXT, ATTR_KEY_KEYWORD, ATTR_KEY_INTEGER, ATTR_KEY_FLOAT, ATTR_KEY_BOOLEAN,
                                   ATTR_KEY_TIME, ATTR_KEY_KEYWORD_LIST)
    end

    def ensure_search_attribute_keys(*keys)
      # Do a list and collect ones not present
      list_resp = client.operator_service.list_search_attributes(
        Temporalio::Api::OperatorService::V1::ListSearchAttributesRequest.new(namespace: client.namespace)
      )

      # Add every one not already present
      to_add = keys.reject { |key| list_resp.custom_attributes.has_key?(key.name) } # rubocop:disable Style/PreferredHashMethods
      return if to_add.empty?

      client.operator_service.add_search_attributes(
        Temporalio::Api::OperatorService::V1::AddSearchAttributesRequest.new(
          namespace: client.namespace,
          search_attributes: to_add.to_h { |key| [key.name, key.type] }
        )
      )

      # List again, confirm all present
      list_resp = client.operator_service.list_search_attributes(
        Temporalio::Api::OperatorService::V1::ListSearchAttributesRequest.new(namespace: client.namespace)
      )
      raise 'Missing keys' unless keys.all? { |key| list_resp.custom_attributes.has_key?(key.name) } # rubocop:disable Style/PreferredHashMethods
    end
  end
end
