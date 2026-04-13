# frozen_string_literal: true

module Temporalio
  module Contrib
    module ToolRegistry
      # Abstract base for LLM provider adapters.
      #
      # Subclasses implement {run_turn} to drive one round-trip with the LLM:
      # send the current message history and available tool definitions, then
      # return any new messages and whether the conversation is complete.
      class Provider
        # Execute one conversation turn.
        #
        # @param messages [Array<Hash>] Current message history (String-keyed).
        # @param tools [Array<ToolDef>] Available tool definitions.
        # @return [Array(Array<Hash>, Boolean)] Tuple of [new_messages, done].
        #   - new_messages: messages to append to the conversation history.
        #   - done: true if the LLM produced a final response with no pending tool calls.
        def run_turn(messages, tools)
          raise NotImplementedError, "#{self.class}#run_turn not implemented"
        end
      end
    end
  end
end
