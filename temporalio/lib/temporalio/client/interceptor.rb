# frozen_string_literal: true

module Temporalio
  class Client
    # Mixin for intercepting clients. Classes that +include+ this should implement their own {intercept_client} that
    # returns their own instance of {Outbound}.
    #
    # @note Input classes herein may get new requeired fields added and therefore the constructors of the Input
    # classes may change in backwards incompatible ways. Users should not try to construct Input classes themselves.
    module Interceptor
      # Method called when intercepting a client. This is called upon client creation.
      #
      # @param next_interceptor [Outbound] Next interceptor in the chain that should be called. This is usually passed
      #   to {Outbound} constructor.
      # @return [Outbound] Interceptor to be called for client calls.
      def intercept_client(next_interceptor)
        next_interceptor
      end

      # Input for {Outbound.start_workflow}.
      StartWorkflowInput = Struct.new(
        :workflow,
        :args,
        :id,
        :task_queue,
        :execution_timeout,
        :run_timeout,
        :task_timeout,
        :id_reuse_policy,
        :id_conflict_policy,
        :retry_policy,
        :cron_schedule,
        :memo,
        :search_attributes,
        :start_delay,
        :request_eager_start,
        :headers,
        :rpc_metadata,
        :rpc_timeout,
        keyword_init: true
      )

      # Input for {Outbound.fetch_workflow_history_event_page}.
      FetchWorkflowHistoryEventPageInput = Struct.new(
        :id,
        :run_id,
        :page_size,
        :next_page_token,
        :wait_new_event,
        :event_filter_type,
        :skip_archival,
        :rpc_metadata,
        :rpc_timeout,
        keyword_init: true
      )

      # Output for {Outbound.fetch_workflow_history_event_page}.
      FetchWorkflowHistoryEventPage = Struct.new(
        :events,
        :next_page_token,
        keyword_init: true
      )

      # Outbound interceptor for intercepting client calls. This should be extended by users needing to intercept client
      # actions.
      class Outbound
        # @return [Outbound] Next interceptor in the chain.
        attr_reader :next_interceptor

        # Initialize outbound with the next interceptor in the chain.
        #
        # @param next_interceptor [Outbound] Next interceptor in the chain.
        def initialize(next_interceptor)
          @next_interceptor = next_interceptor
        end

        # Called for every {Client.start_workflow} and {Client.execute_workflow} call.
        #
        # @param input [StartWorkflowInput] Input.
        # @return [WorkflowHandle] Workflow handle.
        def start_workflow(input)
          next_interceptor.start_workflow(input)
        end

        # Called everytime the client needs a page of workflow history. This includes getting the result.
        #
        # @param input [FetchWorkflowHistoryEventPageInput] Input.
        # @return [FetchWorkflowHistoryEventPage] Event page.
        def fetch_workflow_history_event_page(input)
          next_interceptor.fetch_workflow_history_event_page(input)
        end
      end
    end
  end
end
