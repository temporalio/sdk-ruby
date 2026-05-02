# frozen_string_literal: true

require 'json'
require 'temporalio/contrib/tool_registry/provider'

module Temporalio
  module Contrib
    module ToolRegistry
      module Providers
        # LLM provider adapter for the Anthropic Messages API.
        #
        # Requires the +anthropic+ gem. Install it separately:
        #   gem 'anthropic'
        #
        # The registry passed to the constructor is used to dispatch tool calls
        # that the model requests. Tool definitions are passed via {run_turn}'s
        # +tools+ parameter (typically +registry.defs+).
        class AnthropicProvider < Provider
          DEFAULT_MODEL = 'claude-sonnet-4-6'

          # @param registry [Registry] Registry used to dispatch tool calls.
          # @param system [String] System prompt sent on every turn.
          # @param model [String] Anthropic model ID.
          # @param api_key [String, nil] API key (falls back to +ANTHROPIC_API_KEY+ env var).
          # @param base_url [String, nil] Optional custom base URL.
          # @param client [Object, nil] Pre-built Anthropic client (skips key/URL).
          def initialize(registry, system, model: DEFAULT_MODEL, api_key: nil, base_url: nil, client: nil)
            super()

            @registry = registry
            @system = system
            @model = model
            @client = client || build_client(api_key, base_url)
          end

          # @see Provider#run_turn
          def run_turn(messages, tools)
            anthropic_tools = tools.map do |t|
              { name: t.name, description: t.description, input_schema: t.input_schema }
            end

            resp = @client.messages.create(
              model: @model,
              max_tokens: 4096,
              system: @system,
              messages: messages,
              tools: anthropic_tools
            )

            # JSON round-trip: convert typed SDK objects → plain Hashes for
            # heartbeat safety and consistent message format across all turns.
            content = JSON.parse(JSON.generate(resp.content))
            new_msgs = [{ 'role' => 'assistant', 'content' => content }]

            tool_calls = content.select { |b| b['type'] == 'tool_use' }
            stop_reason = resp.stop_reason.to_s
            return [new_msgs, true] if tool_calls.empty? || stop_reason == 'end_turn'

            tool_results = tool_calls.map do |call|
              is_error = false
              result = begin
                @registry.dispatch(call['name'], call['input'])
              rescue => e # rubocop:disable Style/RescueStandardError
                is_error = true
                "error: #{e.message}"
              end
              entry = { 'type' => 'tool_result', 'tool_use_id' => call['id'], 'content' => result.to_s }
              entry['is_error'] = true if is_error
              entry
            end
            new_msgs << { 'role' => 'user', 'content' => tool_results }
            [new_msgs, false]
          end

          private

          def build_client(api_key, base_url)
            require 'anthropic'
            key = api_key || ENV.fetch('ANTHROPIC_API_KEY')
            opts = { api_key: key }
            opts[:base_url] = base_url if base_url
            Anthropic::Client.new(**opts)
          end
        end
      end
    end
  end
end
