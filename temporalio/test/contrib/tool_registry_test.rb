# frozen_string_literal: true

require 'minitest/autorun'
require 'temporalio/contrib/tool_registry'
require 'temporalio/contrib/tool_registry/testing'

module Contrib
  # Tests for Registry, module-level run_tool_loop, and Provider base class.
  class ToolRegistryTest < Minitest::Test
    Registry = Temporalio::Contrib::ToolRegistry::Registry
    ToolDef = Temporalio::Contrib::ToolRegistry::ToolDef
    Provider = Temporalio::Contrib::ToolRegistry::Provider
    Testing = Temporalio::Contrib::ToolRegistry::Testing

    # ── Registry ──────────────────────────────────────────────────────────────

    def test_register_and_dispatch
      r = Registry.new
      r.register(name: 'echo', description: 'Echo input', input_schema: { 'type' => 'object' }) do |input|
        input['value']
      end
      assert_equal 'hello', r.dispatch('echo', { 'value' => 'hello' })
    end

    def test_dispatch_unknown_tool_raises
      r = Registry.new
      assert_raises(KeyError) { r.dispatch('missing', {}) }
    end

    def test_defs_returns_frozen_copy
      r = Registry.new
      r.register(name: 'a', description: 'd', input_schema: {}) { 'ok' }
      defs = r.defs
      assert_equal 1, defs.size
      assert_instance_of ToolDef, defs.first
      assert_equal 'a', defs.first.name
      assert defs.frozen?
    end

    def test_defs_copy_is_independent
      r = Registry.new
      r.register(name: 'a', description: 'd', input_schema: {}) { 'ok' }
      defs1 = r.defs
      r.register(name: 'b', description: 'd', input_schema: {}) { 'ok' }
      assert_equal 1, defs1.size
      assert_equal 2, r.defs.size
    end

    def test_register_requires_block
      r = Registry.new
      assert_raises(ArgumentError) { r.register(name: 'x', description: 'd', input_schema: {}) }
    end

    def test_to_anthropic
      r = Registry.new
      r.register(name: 'ping', description: 'Ping', input_schema: { 'type' => 'object' }) { 'pong' }
      result = r.to_anthropic
      assert_equal 1, result.size
      assert_equal 'ping', result.first['name']
      assert_equal 'Ping', result.first['description']
      assert_equal({ 'type' => 'object' }, result.first['input_schema'])
    end

    def test_to_openai
      r = Registry.new
      r.register(name: 'ping', description: 'Ping', input_schema: { 'type' => 'object' }) { 'pong' }
      result = r.to_openai
      assert_equal 1, result.size
      item = result.first
      assert_equal 'function', item['type']
      assert_equal 'ping', item.dig('function', 'name')
      assert_equal 'Ping', item.dig('function', 'description')
      assert_equal({ 'type' => 'object' }, item.dig('function', 'parameters'))
    end

    def test_to_openai_empty
      r = Registry.new
      assert_equal [], r.to_openai
    end

    # ── ToolDef ───────────────────────────────────────────────────────────────

    def test_tool_def_is_immutable
      defn = ToolDef.new(name: 'x', description: 'd', input_schema: {})
      assert_raises(NoMethodError) { defn.name = 'y' }
    end

    # ── Provider abstract base ────────────────────────────────────────────────

    def test_provider_run_turn_raises_not_implemented
      p = Provider.new
      assert_raises(NotImplementedError) { p.run_turn([], []) }
    end

    # ── Module-level run_tool_loop ─────────────────────────────────────────────

    def test_module_run_tool_loop_fresh
      registry = Registry.new
      provider = Testing::MockProvider.new(Testing::MockResponse.done('result'))

      messages = Temporalio::Contrib::ToolRegistry.run_tool_loop(provider, registry, 'user prompt')

      assert_equal 2, messages.size
      assert_equal 'user', messages[0]['role']
      assert_equal 'user prompt', messages[0]['content']
      assert_equal 'assistant', messages[1]['role']
    end

    def test_module_run_tool_loop_with_tool_call
      collected = []
      registry = Testing::FakeToolRegistry.new
      registry.register(name: 'collect', description: 'd', input_schema: { 'type' => 'object' }) do |input|
        collected << input['v']
        'collected'
      end
      provider = Testing::MockProvider.new(
        Testing::MockResponse.tool_call('collect', { 'v' => 'item' }),
        Testing::MockResponse.done('done')
      ).with_registry(registry)

      messages = Temporalio::Contrib::ToolRegistry.run_tool_loop(provider, registry, 'go')

      assert_equal ['item'], collected
      assert messages.size > 2
    end

    # ── Integration tests (skipped unless RUN_INTEGRATION_TESTS is set) ─────────

    def make_record_registry
      collected = []
      registry = Registry.new
      registry.register(
        name: 'record',
        description: 'Record a value',
        input_schema: {
          'type' => 'object',
          'properties' => { 'value' => { 'type' => 'string' } },
          'required' => ['value']
        }
      ) do |input|
        collected << input['value']
        'recorded'
      end
      [registry, collected]
    end

    def test_integration_anthropic
      skip 'RUN_INTEGRATION_TESTS not set' unless ENV['RUN_INTEGRATION_TESTS']
      api_key = ENV['ANTHROPIC_API_KEY']
      skip 'ANTHROPIC_API_KEY not set' unless api_key

      require 'temporalio/contrib/tool_registry/providers/anthropic'
      registry, collected = make_record_registry
      provider = Temporalio::Contrib::ToolRegistry::Providers::AnthropicProvider.new(
        registry,
        "You must call record() exactly once with value='hello'.",
        api_key: api_key
      )
      Temporalio::Contrib::ToolRegistry.run_tool_loop(
        provider, registry,
        "Please call the record tool with value='hello'."
      )
      assert_includes collected, 'hello'
    end

    # ── from_mcp_tools ────────────────────────────────────────────────────────

    def test_from_mcp_tools
      t1 = Struct.new(:name, :description, :input_schema).new(
        'read_file', 'Read a file',
        { 'type' => 'object', 'properties' => { 'path' => { 'type' => 'string' } } }
      )
      t2 = Struct.new(:name, :description, :input_schema).new('list_dir', nil, nil)

      reg = Registry.from_mcp_tools([t1, t2])

      assert_equal 2, reg.defs.size
      assert_equal 'read_file', reg.defs[0].name
      assert_equal 'Read a file', reg.defs[0].description
      assert_equal 'list_dir', reg.defs[1].name
      assert_equal 'object', reg.defs[1].input_schema['type'] # nil schema → empty object schema
      assert_equal '', reg.dispatch('read_file', { 'path' => '/etc/hosts' })
    end

    def test_integration_openai
      skip 'RUN_INTEGRATION_TESTS not set' unless ENV['RUN_INTEGRATION_TESTS']
      api_key = ENV['OPENAI_API_KEY']
      skip 'OPENAI_API_KEY not set' unless api_key

      require 'temporalio/contrib/tool_registry/providers/openai'
      registry, collected = make_record_registry
      provider = Temporalio::Contrib::ToolRegistry::Providers::OpenAIProvider.new(
        registry,
        "You must call record() exactly once with value='hello'.",
        api_key: api_key
      )
      Temporalio::Contrib::ToolRegistry.run_tool_loop(
        provider, registry,
        "Please call the record tool with value='hello'."
      )
      assert_includes collected, 'hello'
    end
  end
end
