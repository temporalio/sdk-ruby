# frozen_string_literal: true

require 'json'
require 'temporalio/activity/context'
require 'temporalio/error/failure'

module Temporalio
  module Contrib
    module ToolRegistry
      # Holds conversation state across a multi-turn LLM tool-use loop.
      #
      # On activity retry, {run_with_session} restores the session from the last
      # heartbeat checkpoint so the conversation resumes mid-turn rather than
      # restarting from the beginning.
      class AgenticSession
        # @return [Array<Hash>] Full conversation history (String-keyed, JSON-safe).
        attr_reader :messages

        # @return [Array<Hash>] Application-level results from tool calls.
        attr_reader :issues

        # Run +block+ with a durable, checkpointed LLM session.
        #
        # On entry it reads the last heartbeat checkpoint from the activity
        # context. If found, the session is restored so the conversation resumes
        # mid-turn rather than restarting from turn 0.
        #
        # Must be called inside a Temporal activity (requires an active
        # {Activity::Context}).
        #
        # @yield [AgenticSession] Freshly created (or restored) session.
        def self.run_with_session
          session = new
          ctx = Activity::Context.current
          details = ctx.info.heartbeat_details
          cp = details&.first
          if cp.is_a?(Hash)
            session.send(:restore, cp)
          elsif !cp.nil?
            ctx.logger.warn("AgenticSession: corrupt checkpoint (#{cp.class}), starting fresh")
          end
          yield session
        end

        def initialize
          @messages = []
          @issues = []
        end

        private

        def restore(checkpoint)
          return unless checkpoint.is_a?(Hash)

          v = checkpoint['version']
          if v.nil?
            Activity::Context.current.logger.warn(
              'AgenticSession: checkpoint has no version field — may be from an older release'
            )
          elsif v != 1
            Activity::Context.current.logger.warn(
              "AgenticSession: checkpoint version #{v}, expected 1 — starting fresh"
            )
            return
          end

          @messages = Array(checkpoint['messages'])
          @issues = Array(checkpoint['issues'])
        end

        public

        # Append an application-level issue record.
        #
        # @param issue_hash [Hash] JSON-serializable issue.
        def add_issue(issue_hash)
          @issues << issue_hash
        end

        # Run the agentic tool-use loop to completion.
        #
        # If {messages} is empty (fresh start), +prompt+ is added as the first
        # user message. Otherwise the existing conversation state is resumed
        # (retry case).
        #
        # On every turn it checkpoints via {Activity::Context#heartbeat} before
        # calling the provider. Ruby's +CanceledError+ is raised asynchronously
        # through the next blocking call when the activity is cancelled; no
        # explicit check after heartbeat is needed.
        #
        # @param provider [Provider] LLM provider adapter.
        # @param registry [Registry] Tool registry whose definitions are passed to the LLM.
        # @param prompt [String] Initial user prompt (ignored on retry).
        def run_tool_loop(provider, registry, prompt)
          @messages << { 'role' => 'user', 'content' => prompt } if @messages.empty?

          loop do
            checkpoint
            new_msgs, done = provider.run_turn(@messages, registry.defs)
            @messages.concat(new_msgs)
            break if done
          end
        end

        # Heartbeat the current session state to Temporal.
        #
        # Call this inside an activity context. On cancellation, +CanceledError+
        # arrives asynchronously through the next blocking call (the LLM HTTP
        # request) — no explicit check is needed after calling +checkpoint+.
        #
        # @raise [Temporalio::Error::ApplicationError] (non-retryable) if any issue is not
        #   JSON-serializable.
        def checkpoint
          @issues.each_with_index do |issue, i|
            JSON.generate(issue)
          rescue TypeError, JSON::GeneratorError => e
            raise Temporalio::Error::ApplicationError.new(
              "AgenticSession: issues[#{i}] is not JSON-serializable: #{e}. " \
              'Store only Hash values with JSON-serializable content.',
              non_retryable: true
            )
          end
          Activity::Context.current.heartbeat('version' => 1, 'messages' => @messages, 'issues' => @issues)
        end
      end
    end
  end
end
