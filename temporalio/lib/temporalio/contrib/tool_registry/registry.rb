# frozen_string_literal: true

require 'json'

module Temporalio
  module Contrib
    module ToolRegistry
      # Immutable definition of a single LLM-callable tool.
      ToolDef = Data.define(:name, :description, :input_schema)

      # Registry that maps tool names to handlers.
      class Registry
        def initialize
          @defs = []
          @handlers = {}
        end

        # Build a Registry from a list of MCP tool descriptors.
        #
        # Each descriptor must respond to +name+, +description+, and +input_schema+
        # (or +inputSchema+ for camelCase MCP objects). No-op handlers (returning an
        # empty string) are registered for each tool — override them with {#register}
        # after construction.
        #
        # @param tools [Array] MCP tool descriptor objects.
        # @return [Registry]
        def self.from_mcp_tools(tools)
          registry = new
          tools.each do |tool|
            schema = (tool.respond_to?(:input_schema) ? tool.input_schema : tool.inputSchema) ||
                     { 'type' => 'object', 'properties' => {} }
            desc = (tool.respond_to?(:description) ? tool.description : nil) || ''
            registry.register(
              name: tool.name,
              description: desc,
              input_schema: schema
            ) { |_input| '' }
          end
          registry
        end

        # Register a tool with the given name, description, and JSON Schema for its input.
        # The block receives a Hash of parsed arguments and must return a String result.
        #
        # @param name [String] Tool name.
        # @param description [String] Human-readable description.
        # @param input_schema [Hash] JSON Schema for the tool's input object.
        # @yield [Hash] Called with the parsed input when the tool is invoked.
        # @return [self]
        def register(name:, description:, input_schema:, &handler)
          raise ArgumentError, 'Block required' unless block_given?

          defn = ToolDef.new(name: name.to_s, description: description.to_s, input_schema:)
          @defs << defn
          @handlers[defn.name] = handler
          self
        end

        # Dispatch a tool call by name. Raises KeyError if the tool is not registered.
        #
        # @param name [String] Tool name.
        # @param input [Hash] Parsed input arguments.
        # @return [String] Tool result.
        def dispatch(name, input)
          handler = @handlers.fetch(name.to_s) { raise KeyError, "Unknown tool: #{name}" }
          handler.call(input)
        end

        # @return [Array<ToolDef>] Frozen copy of all registered tool definitions.
        def defs
          @defs.dup.freeze
        end

        # @return [Array<Hash>] Tool definitions in Anthropic API format.
        def to_anthropic
          @defs.map do |t|
            { 'name' => t.name, 'description' => t.description, 'input_schema' => t.input_schema }
          end
        end

        # @return [Array<Hash>] Tool definitions in OpenAI function-calling format.
        def to_openai
          @defs.map do |t|
            {
              'type' => 'function',
              'function' => {
                'name' => t.name,
                'description' => t.description,
                'parameters' => t.input_schema
              }
            }
          end
        end
      end
    end
  end
end
