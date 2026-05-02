# frozen_string_literal: true

require 'minitest/autorun'
require 'temporalio/activity/context'
require 'temporalio/contrib/tool_registry'
require 'temporalio/contrib/tool_registry/testing'

module Contrib
  # Tests for AgenticSession: run_tool_loop, checkpoint, and run_with_session.
  #
  # These tests run without a Temporal server or native bridge by manually
  # wiring a lightweight fake activity context into Thread.current.
  class ToolRegistrySessionTest < Minitest::Test
    AgenticSession = Temporalio::Contrib::ToolRegistry::AgenticSession
    Registry = Temporalio::Contrib::ToolRegistry::Registry
    Testing = Temporalio::Contrib::ToolRegistry::Testing

    # ── Test harness ──────────────────────────────────────────────────────────

    # Minimal activity context used in session tests.
    class FakeContext < Temporalio::Activity::Context
      attr_reader :heartbeats, :warnings

      def initialize(heartbeat_details: [])
        @heartbeats = []
        @warnings = []
        @info = FakeInfo.new(heartbeat_details)
        @logger = FakeLogger.new(@warnings)
      end

      def heartbeat(*details)
        @heartbeats << details
      end

      def info
        @info
      end

      def logger
        @logger
      end
    end

    # Stub logger that captures warnings for assertions.
    class FakeLogger
      def initialize(warnings)
        @warnings = warnings
      end

      def warn(msg)
        @warnings << msg
      end
    end

    # Minimal Info that returns pre-seeded heartbeat details directly.
    class FakeInfo
      def initialize(details)
        @details = details
      end

      def heartbeat_details(hints: nil)
        @details
      end
    end

    # Minimal executor whose #activity_context returns the given FakeContext.
    class FakeExecutor
      def initialize(context)
        @context = context
      end

      def activity_context
        @context
      end
    end

    # Run a block inside a fake activity context.
    def in_activity(ctx = FakeContext.new)
      original = Thread.current[:temporal_activity_executor]
      Thread.current[:temporal_activity_executor] = FakeExecutor.new(ctx)
      yield ctx
    ensure
      Thread.current[:temporal_activity_executor] = original
    end

    # ── AgenticSession ────────────────────────────────────────────────────────

    def test_fresh_start_seeds_user_message
      registry = Registry.new
      provider = Testing::MockProvider.new(Testing::MockResponse.done('done'))
      captured = nil

      in_activity do
        session = AgenticSession.new
        session.run_tool_loop(provider, registry, 'hello')
        captured = session.messages
      end

      assert_equal 'user', captured[0]['role']
      assert_equal 'hello', captured[0]['content']
      assert_equal 'assistant', captured[1]['role']
    end

    def test_existing_messages_skip_prompt
      checkpoint = {
        'messages' => [{ 'role' => 'user', 'content' => 'original' }],
        'issues' => []
      }
      ctx = FakeContext.new(heartbeat_details: [checkpoint])
      registry = Registry.new
      provider = Testing::MockProvider.new(Testing::MockResponse.done('ok'))
      captured = nil

      in_activity(ctx) do
        AgenticSession.run_with_session do |session|
          session.run_tool_loop(provider, registry, 'ignored')
          captured = session.messages
        end
      end

      assert_equal 'original', captured[0]['content']
      assert_equal 'assistant', captured[1]['role']
    end

    def test_tool_call_dispatched
      collected = []
      fake_reg = Testing::FakeToolRegistry.new
      fake_reg.register(name: 'collect', description: 'd', input_schema: { 'type' => 'object' }) do |input|
        collected << input['v']
        'ok'
      end
      provider = Testing::MockProvider.new(
        Testing::MockResponse.tool_call('collect', { 'v' => 'first' }),
        Testing::MockResponse.tool_call('collect', { 'v' => 'second' }),
        Testing::MockResponse.done('done')
      ).with_registry(fake_reg)

      captured = nil
      in_activity do
        session = AgenticSession.new
        session.run_tool_loop(provider, fake_reg, 'go')
        captured = session.messages
      end

      assert_equal %w[first second], collected
      # user + (assistant + user)*2 + final_assistant = at least 5
      assert captured.size > 4
    end

    def test_checkpoint_called_each_turn
      registry = Registry.new
      provider = Testing::MockProvider.new(Testing::MockResponse.done('x'))
      ctx = FakeContext.new

      in_activity(ctx) do
        session = AgenticSession.new
        session.run_tool_loop(provider, registry, 'prompt')
      end

      # checkpoint is called once before the first (and only) turn
      assert_equal 1, ctx.heartbeats.size
      detail = ctx.heartbeats.first.first
      assert detail.is_a?(Hash)
      assert detail.key?('messages')
      assert detail.key?('issues')
    end

    def test_add_issue
      session = AgenticSession.new
      session.add_issue({ 'type' => 'error', 'msg' => 'oops' })
      assert_equal 1, session.issues.size
      assert_equal 'error', session.issues.first['type']
    end

    # ── run_with_session ──────────────────────────────────────────────────────

    def test_run_with_session_fresh_start
      registry = Registry.new
      provider = Testing::MockProvider.new(Testing::MockResponse.done('done'))
      captured = nil

      in_activity do
        AgenticSession.run_with_session do |session|
          session.run_tool_loop(provider, registry, 'hello')
          captured = session.messages
        end
      end

      refute_nil captured
      assert_equal 'hello', captured[0]['content']
    end

    def test_run_with_session_restores_checkpoint
      checkpoint = {
        'messages' => [{ 'role' => 'user', 'content' => 'restored' }],
        'issues' => [{ 'code' => 42 }]
      }
      ctx = FakeContext.new(heartbeat_details: [checkpoint])
      registry = Registry.new
      provider = Testing::MockProvider.new(Testing::MockResponse.done('done'))
      captured_messages = nil
      captured_issues = nil

      in_activity(ctx) do
        AgenticSession.run_with_session do |session|
          session.run_tool_loop(provider, registry, 'ignored')
          captured_messages = session.messages
          captured_issues = session.issues
        end
      end

      assert_equal 'restored', captured_messages[0]['content']
      assert_equal [{ 'code' => 42 }], captured_issues
    end

    # ── Checkpoint round-trip test (T6) ──────────────────────────────────────

    def test_checkpoint_round_trip_preserves_tool_calls
      # Simulate a real Temporal round-trip: the heartbeat payload is JSON-serialized
      # and deserialized by the Temporal server between activity attempts.
      tool_calls = [
        {
          'id' => 'call_abc',
          'type' => 'function',
          'function' => { 'name' => 'my_tool', 'arguments' => '{"x":1}' }
        }
      ]
      assistant_msg = { 'role' => 'assistant', 'tool_calls' => tool_calls }
      issue = { 'type' => 'smell', 'file' => 'foo.rb' }

      ctx = FakeContext.new
      in_activity(ctx) do
        session = AgenticSession.new
        session.instance_variable_set(:@messages, [assistant_msg])
        session.instance_variable_set(:@issues, [issue])
        session.checkpoint
      end

      assert_equal 1, ctx.heartbeats.size
      raw_payload = ctx.heartbeats.first.first

      # Simulate JSON round-trip as Temporal would apply between activity attempts.
      json = JSON.generate(raw_payload)
      restored_payload = JSON.parse(json)

      assert_equal 'assistant', restored_payload['messages'][0]['role']
      tool_calls_restored = restored_payload['messages'][0]['tool_calls']
      assert_instance_of Array, tool_calls_restored
      assert_equal 1, tool_calls_restored.size
      assert_equal 'call_abc', tool_calls_restored[0]['id']
      assert_equal 'my_tool', tool_calls_restored[0]['function']['name']
      assert_equal 'smell', restored_payload['issues'][0]['type']
      assert_equal 'foo.rb', restored_payload['issues'][0]['file']
    end

    def test_run_with_session_ignores_non_hash_checkpoint
      # nil / non-Hash heartbeat details → fresh start
      ctx = FakeContext.new(heartbeat_details: [42])
      registry = Registry.new
      provider = Testing::MockProvider.new(Testing::MockResponse.done('done'))
      captured = nil

      in_activity(ctx) do
        AgenticSession.run_with_session do |session|
          session.run_tool_loop(provider, registry, 'fresh')
          captured = session.messages
        end
      end

      assert_equal 'fresh', captured[0]['content']
    end
  end
end
