# frozen_string_literal: true

require 'json'
require 'temporalio/contrib/tool_registry/provider'

module Temporalio
  module Contrib
    module ToolRegistry
      module Providers
        # LLM provider adapter for the OpenAI Chat Completions API.
        #
        # Requires the +ruby-openai+ gem. Install it separately:
        #   gem 'ruby-openai'
        #
        # The registry passed to the constructor is used to dispatch tool calls
        # that the model requests. Tool definitions are passed via {run_turn}'s
        # +tools+ parameter (typically +registry.defs+).
        class OpenAIProvider < Provider
          DEFAULT_MODEL = 'gpt-4o'

          # @param registry [Registry] Registry used to dispatch tool calls.
          # @param system [String] System prompt prepended as a system message.
          # @param model [String] OpenAI model ID.
          # @param api_key [String, nil] API key (falls back to +OPENAI_API_KEY+ env var).
          # @param base_url [String, nil] Optional custom base URL.
          # @param client [Object, nil] Pre-built OpenAI client (skips key/URL).
          def initialize(registry, system, model: DEFAULT_MODEL, api_key: nil, base_url: nil, client: nil)
            super()
            require 'openai'

            @registry = registry
            @system = system
            @model = model
            @client = client || build_client(api_key, base_url)
          end

          # @see Provider#run_turn
          def run_turn(messages, tools)
            full_messages = [{ 'role' => 'system', 'content' => @system }] + messages
            openai_tools = tools.map do |t|
              {
                'type' => 'function',
                'function' => {
                  'name' => t.name,
                  'description' => t.description,
                  'parameters' => t.input_schema
                }
              }
            end

            resp = @client.chat(parameters: {
                                  model: @model,
                                  messages: full_messages,
                                  tools: openai_tools
                                })

            choice = resp.dig('choices', 0)
            msg = choice&.dig('message') || {}

            msg_hash = { 'role' => 'assistant', 'content' => msg['content'] }
            tool_calls = msg['tool_calls'] || []

            unless tool_calls.empty?
              msg_hash['tool_calls'] = tool_calls.map do |tc|
                {
                  'id' => tc['id'],
                  'type' => 'function',
                  'function' => {
                    'name' => tc.dig('function', 'name'),
                    'arguments' => tc.dig('function', 'arguments')
                  }
                }
              end
            end

            new_msgs = [msg_hash]
            finish_reason = choice&.dig('finish_reason') || ''
            done = tool_calls.empty? || %w[stop length].include?(finish_reason)
            return [new_msgs, true] if done

            tool_calls.each do |tc|
              input = JSON.parse(tc.dig('function', 'arguments') || '{}')
              name = tc.dig('function', 'name')
              result = begin
                @registry.dispatch(name, input)
              rescue => e # rubocop:disable Style/RescueStandardError
                "error: #{e.message}"
              end
              new_msgs << {
                'role' => 'tool',
                'tool_call_id' => tc['id'],
                'content' => result.to_s
              }
            end
            [new_msgs, false]
          end

          private

          def build_client(api_key, base_url)
            key = api_key || ENV.fetch('OPENAI_API_KEY')
            opts = { access_token: key }
            opts[:uri_base] = base_url if base_url
            OpenAI::Client.new(**opts)
          end
        end
      end
    end
  end
end
