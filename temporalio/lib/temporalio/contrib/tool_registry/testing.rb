# frozen_string_literal: true

require 'securerandom'
require 'temporalio/contrib/tool_registry/provider'
require 'temporalio/contrib/tool_registry/registry'
require 'temporalio/contrib/tool_registry/session'

module Temporalio
  module Contrib
    module ToolRegistry
      module Testing
        # A recorded tool dispatch (name, input, result).
        DispatchCall = Data.define(:name, :input, :result)

        # A canned response to be returned by {MockProvider}.
        #
        # Use the factory methods {done} and {tool_call} to build instances.
        class MockResponse
          # @return [Symbol] :done or :tool_call
          attr_reader :type
          # @return [String, nil] Text content for :done responses.
          attr_reader :text
          # @return [String, nil] Tool name for :tool_call responses.
          attr_reader :tool_name
          # @return [Hash, nil] Tool input for :tool_call responses.
          attr_reader :input
          # @return [String, nil] Explicit call ID (auto-generated if nil).
          attr_reader :call_id

          # Build a "done" response with the given text.
          #
          # @param text [String]
          # @return [MockResponse]
          def self.done(text)
            new(:done, text:)
          end

          # Build a "tool_call" response.
          #
          # @param tool_name [String] Tool to call.
          # @param input [Hash] Input for the tool.
          # @param call_id [String, nil] Optional explicit call ID.
          # @return [MockResponse]
          def self.tool_call(tool_name, input, call_id = nil)
            new(:tool_call, tool_name:, input:, call_id:)
          end

          private

          def initialize(type, text: nil, tool_name: nil, input: nil, call_id: nil)
            @type = type
            @text = text
            @tool_name = tool_name
            @input = input
            @call_id = call_id
          end
        end

        # A {Provider} backed by pre-scripted {MockResponse} values.
        #
        # When a tool-call response is scripted and a registry is wired via
        # {with_registry}, the provider dispatches the tool call and adds the
        # result as a user message.
        class MockProvider < Provider
          def initialize(*responses)
            super()
            @responses = responses.dup
            @registry = nil
          end

          # Wire a registry so tool-call responses can dispatch tools.
          #
          # @param registry [Registry]
          # @return [self]
          def with_registry(registry)
            @registry = registry
            self
          end

          # @see Provider#run_turn
          def run_turn(_messages, _tools)
            raise 'MockProvider: no more responses' if @responses.empty?

            resp = @responses.shift

            case resp.type
            when :done
              text_block = { 'type' => 'text', 'text' => resp.text }
              [[{ 'role' => 'assistant', 'content' => [text_block] }], true]

            when :tool_call
              reg = @registry or raise 'MockProvider: tool_call response requires a registry (use #with_registry)'
              call_id = resp.call_id || "mock-call-#{SecureRandom.hex(4)}"
              tool_block = {
                'type' => 'tool_use',
                'id' => call_id,
                'name' => resp.tool_name,
                'input' => resp.input
              }
              new_msgs = [{ 'role' => 'assistant', 'content' => [tool_block] }]
              result = begin
                reg.dispatch(resp.tool_name, resp.input)
              rescue => e # rubocop:disable Style/RescueStandardError
                "error: #{e.message}"
              end
              new_msgs << {
                'role' => 'user',
                'content' => [{ 'type' => 'tool_result', 'tool_use_id' => call_id, 'content' => result.to_s }]
              }
              [new_msgs, false]

            else
              raise "MockProvider: unknown response type #{resp.type.inspect}"
            end
          end
        end

        # A {Registry} subclass that records every {dispatch} call.
        class FakeToolRegistry < Registry
          # @return [Array<DispatchCall>] All recorded dispatch calls.
          def calls
            @calls ||= []
          end

          # @see Registry#dispatch
          def dispatch(name, input)
            result = super
            calls << DispatchCall.new(name:, input:, result:)
            result
          end
        end

        # A {AgenticSession} whose {run_tool_loop} is a no-op for isolation tests.
        #
        # Useful when you want to test code that *holds* a session reference
        # without actually driving the LLM loop.
        class MockAgenticSession < AgenticSession
          # @return [String, nil] The prompt passed to the last {run_tool_loop} call.
          attr_reader :captured_prompt

          # Override: records the prompt but does not call the LLM.
          def run_tool_loop(_provider, _registry, _system, prompt)
            @captured_prompt = prompt
          end

          # Expose issues array for pre-seeding in tests.
          #
          # @return [Array<Hash>]
          def mutable_issues
            @issues
          end
        end

        # A {Provider} decorator that raises after a given number of turns.
        #
        # Useful for testing retry / checkpoint-restore behaviour.
        class CrashAfterTurns < Provider
          # @param turns [Integer] Number of successful turns before crashing.
          # @param delegate [Provider, nil] Underlying provider. If nil a
          #   {MockProvider} with a single :done response is used internally.
          def initialize(turns, delegate = nil)
            super()
            @turns = turns
            @delegate = delegate || MockProvider.new(MockResponse.done('ok'))
            @count = 0
          end

          # @see Provider#run_turn
          def run_turn(messages, tools)
            @count += 1
            raise "CrashAfterTurns: crashed after #{@turns} turns" if @count > @turns

            @delegate.run_turn(messages, tools)
          end
        end
      end
    end
  end
end
