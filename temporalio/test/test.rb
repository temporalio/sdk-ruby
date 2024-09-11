# frozen_string_literal: true

require 'extra_assertions'
require 'minitest/autorun'
require 'securerandom'
require 'singleton'
require 'temporalio/testing'
require 'timeout'

class Test < Minitest::Test
  include ExtraAssertions

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
