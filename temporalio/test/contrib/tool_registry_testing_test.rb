# frozen_string_literal: true

require 'minitest/autorun'
require 'temporalio/contrib/tool_registry'
require 'temporalio/contrib/tool_registry/testing'

module Contrib
  # Tests for the testing utilities: MockResponse, MockProvider, FakeToolRegistry,
  # MockAgenticSession, and CrashAfterTurns.
  class ToolRegistryTestingTest < Minitest::Test
    Registry = Temporalio::Contrib::ToolRegistry::Registry
    Testing = Temporalio::Contrib::ToolRegistry::Testing

    # ── MockResponse ──────────────────────────────────────────────────────────

    def test_mock_response_done
      r = Testing::MockResponse.done('all done')
      assert_equal :done, r.type
      assert_equal 'all done', r.text
      assert_nil r.tool_name
    end

    def test_mock_response_tool_call
      r = Testing::MockResponse.tool_call('search', { 'q' => 'ruby' })
      assert_equal :tool_call, r.type
      assert_equal 'search', r.tool_name
      assert_equal({ 'q' => 'ruby' }, r.input)
      assert_nil r.call_id
    end

    def test_mock_response_tool_call_with_id
      r = Testing::MockResponse.tool_call('search', { 'q' => 'ruby' }, 'call-123')
      assert_equal 'call-123', r.call_id
    end

    # ── MockProvider ──────────────────────────────────────────────────────────

    def test_mock_provider_done_response
      provider = Testing::MockProvider.new(Testing::MockResponse.done('finished'))
      msgs, done = provider.run_turn([], [])
      assert done
      assert_equal 1, msgs.size
      assert_equal 'assistant', msgs.first['role']
    end

    def test_mock_provider_tool_call_without_registry_raises
      provider = Testing::MockProvider.new(Testing::MockResponse.tool_call('x', {}))
      assert_raises(RuntimeError) { provider.run_turn([], []) }
    end

    def test_mock_provider_tool_call_dispatches
      registry = Testing::FakeToolRegistry.new
      registry.register(name: 'greet', description: 'd', input_schema: {}) { |i| "Hello #{i['name']}" }

      provider = Testing::MockProvider.new(
        Testing::MockResponse.tool_call('greet', { 'name' => 'World' }),
        Testing::MockResponse.done('bye')
      ).with_registry(registry)

      msgs1, done1 = provider.run_turn([], [])
      refute done1
      assert_equal 2, msgs1.size  # assistant + tool_result user message
      assert_equal 'assistant', msgs1[0]['role']
      assert_equal 'user', msgs1[1]['role']

      msgs2, done2 = provider.run_turn([], [])
      assert done2
    end

    def test_mock_provider_exhausted_raises
      provider = Testing::MockProvider.new(Testing::MockResponse.done('only one'))
      provider.run_turn([], [])
      assert_raises(RuntimeError) { provider.run_turn([], []) }
    end

    def test_mock_provider_uses_explicit_call_id
      registry = Testing::FakeToolRegistry.new
      registry.register(name: 't', description: 'd', input_schema: {}) { 'result' }

      provider = Testing::MockProvider.new(
        Testing::MockResponse.tool_call('t', {}, 'fixed-id')
      ).with_registry(registry)

      msgs, = provider.run_turn([], [])
      # First message is assistant with tool_use content block containing our id
      tool_block = msgs[0]['content'].first
      assert_equal 'fixed-id', tool_block['id']
      # Second message is tool_result referencing the same id
      result_block = msgs[1]['content'].first
      assert_equal 'fixed-id', result_block['tool_use_id']
    end

    # ── FakeToolRegistry ──────────────────────────────────────────────────────

    def test_fake_tool_registry_records_calls
      r = Testing::FakeToolRegistry.new
      r.register(name: 'add', description: 'add', input_schema: {}) { |i| i['a'] + i['b'] }

      r.dispatch('add', { 'a' => 1, 'b' => 2 })
      r.dispatch('add', { 'a' => 10, 'b' => 20 })

      assert_equal 2, r.calls.size
      assert_equal 'add', r.calls.first.name
      assert_equal 3, r.calls.first.result
      assert_equal 30, r.calls.last.result
    end

    def test_fake_tool_registry_inherits_dispatch
      r = Testing::FakeToolRegistry.new
      r.register(name: 'upper', description: 'u', input_schema: {}) { |i| i['s'].upcase }
      assert_equal 'HELLO', r.dispatch('upper', { 's' => 'hello' })
    end

    def test_fake_tool_registry_unknown_tool_raises
      r = Testing::FakeToolRegistry.new
      assert_raises(KeyError) { r.dispatch('no_such', {}) }
    end

    # ── MockAgenticSession ────────────────────────────────────────────────────

    def test_mock_agentic_session_captures_prompt
      registry = Registry.new
      provider = Testing::MockProvider.new(Testing::MockResponse.done('x'))
      session = Testing::MockAgenticSession.new
      session.run_tool_loop(provider, registry, 'sys', 'my prompt')
      assert_equal 'my prompt', session.captured_prompt
    end

    def test_mock_agentic_session_run_tool_loop_is_noop
      registry = Registry.new
      provider = Testing::MockProvider.new  # no responses — would crash if called
      session = Testing::MockAgenticSession.new
      session.run_tool_loop(provider, registry, 'sys', 'whatever')
      assert_empty session.messages  # not modified
    end

    def test_mock_agentic_session_mutable_issues
      session = Testing::MockAgenticSession.new
      session.mutable_issues << { 'type' => 'seed' }
      assert_equal 1, session.issues.size
    end

    # ── CrashAfterTurns ───────────────────────────────────────────────────────

    def test_crash_after_turns_crashes_on_nth_plus_one
      provider = Testing::CrashAfterTurns.new(
        2,
        Testing::MockProvider.new(
          Testing::MockResponse.done('t1'),
          Testing::MockResponse.done('t2'),
          Testing::MockResponse.done('t3')
        )
      )

      provider.run_turn([], [])  # turn 1 — ok
      provider.run_turn([], [])  # turn 2 — ok
      assert_raises(RuntimeError) { provider.run_turn([], []) }  # turn 3 — crash
    end

    def test_crash_after_turns_delegates
      inner = Testing::MockProvider.new(Testing::MockResponse.done('hello'))
      provider = Testing::CrashAfterTurns.new(5, inner)
      msgs, done = provider.run_turn([], [])
      assert done
      assert_equal 'assistant', msgs.first['role']
    end

    # ── DispatchCall ──────────────────────────────────────────────────────────

    def test_dispatch_call_fields
      call = Testing::DispatchCall.new(name: 'fn', input: { 'x' => 1 }, result: 'out')
      assert_equal 'fn', call.name
      assert_equal({ 'x' => 1 }, call.input)
      assert_equal 'out', call.result
    end
  end
end
