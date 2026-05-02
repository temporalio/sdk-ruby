# frozen_string_literal: true

require 'temporalio/contrib/tool_registry/provider'
require 'temporalio/contrib/tool_registry/registry'
require 'temporalio/contrib/tool_registry/session'

module Temporalio
  module Contrib
    # LLM tool-calling primitives for Temporal activities.
    #
    # This module provides building blocks for running agentic LLM tool-use
    # loops inside Temporal activities with automatic heartbeat checkpointing
    # and retry/resume semantics.
    #
    # == Quick-start
    #
    #   registry = Temporalio::Contrib::ToolRegistry::Registry.new
    #   registry.register(name: 'get_weather', description: 'Get the weather',
    #                     input_schema: { type: 'object', properties: { city: { type: 'string' } } }) do |input|
    #     WeatherService.get(input['city'])
    #   end
    #
    #   provider = Temporalio::Contrib::ToolRegistry::Providers::AnthropicProvider.new(
    #     registry, 'You are a helpful assistant.', api_key: ENV['ANTHROPIC_API_KEY']
    #   )
    #
    #   # Inside a Temporal activity:
    #   Temporalio::Contrib::ToolRegistry::AgenticSession.run_with_session do |session|
    #     session.run_tool_loop(provider, registry, 'What is the weather in NYC?')
    #   end
    #
    # == Module-level helper
    #
    # For simple cases that do not require checkpointing (no activity context):
    #
    #   messages = Temporalio::Contrib::ToolRegistry.run_tool_loop(provider, registry, 'user prompt')
    #
    module ToolRegistry
      # Run a single (non-checkpointed) agentic tool-use loop.
      #
      # This is a convenience wrapper that does NOT require an active Temporal
      # activity context. For production use inside activities, prefer
      # {AgenticSession.run_with_session} to get heartbeat checkpointing and
      # automatic retry-resume.
      #
      # @param provider [Provider] LLM provider adapter.
      # @param registry [Registry] Tool registry.
      # @param prompt [String] Initial user prompt.
      # @return [Array<Hash>] Full conversation message history.
      def self.run_tool_loop(provider, registry, prompt)
        messages = [{ 'role' => 'user', 'content' => prompt }]
        loop do
          new_msgs, done = provider.run_turn(messages, registry.defs)
          messages.concat(new_msgs)
          break if done
        end
        messages
      end
    end
  end
end
