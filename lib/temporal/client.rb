require 'json'
require 'securerandom'
require 'socket'
require 'temporal/client/implementation'
require 'temporal/client/workflow_handle'
require 'temporal/data_converter'
require 'temporal/errors'
require 'temporal/failure_converter'
require 'temporal/payload_converter'
require 'temporal/workflow/id_reuse_policy'

module Temporal
  class Client
    # @return [String] Namespace used for client calls.
    attr_reader :namespace

    # Create a Temporal client from a connection.
    #
    # @param connection [Temporal::Connection] A connection to the Temporal server.
    # @param namespace [String] Namespace to use for client calls.
    # @param interceptors [Array<Temporal::Interceptor::Client>] List of interceptors for
    #   intercepting client calls. Executed in their original order.
    # @param data_converter [Temporal::DataConverter] Data converter to use for all data conversions
    #   to/from payloads.
    #
    # @see https://docs.temporal.io/concepts/what-is-a-data-converter for more information on
    #   payload converters and codecs.
    def initialize(
      connection,
      namespace,
      interceptors: [],
      data_converter: Temporal::DataConverter.new
    )
      @namespace = namespace
      @implementation = Client::Implementation.new(connection, namespace, data_converter, interceptors)
    end

    # Start a workflow and return its handle.
    #
    # @param workflow [String] Name of the workflow.
    # @param args [any] Arguments to the workflow.
    # @param id [String] Unique identifier for the workflow execution.
    # @param task_queue [String, Symbol] Task queue to run the workflow on.
    # @param execution_timeout [Integer] Total workflow execution timeout including
    #   retries and continue as new.
    # @param run_timeout [Integer] Timeout of a single workflow run.
    # @param task_timeout [Integer] Timeout of a single workflow task.
    # @param id_reuse_policy [Symbol] How already-existing IDs are treated. Refer to
    #   {Temporal::Workflow::IDReusePolicy} for the list of allowed values.
    # @param retry_policy [Temporal::RetryPolicy] Retry policy for the workflow.
    #   See {Temporal::RetryPolicy}.
    # @param cron_schedule [String] See https://docs.temporal.io/docs/content/what-is-a-temporal-cron-job.
    # @param memo [Hash<String, any>] Memo for the workflow.
    # @param search_attributes [Hash<String, any>] Search attributes for the workflow.
    # @param start_signal [String, Symbol] If present, this signal is sent as signal-with-start
    #   instead of traditional workflow start.
    # @param start_signal_args [Array<any>] Arguments for start_signal if `:start_signal`
    #   present.
    # @param rpc_metadata [Hash<String, String>] Headers used on the RPC call. Keys here override
    #   client-level RPC metadata keys.
    # @param rpc_timeout [Integer] Optional RPC deadline to set for the RPC call.
    #
    # @return [Temporal::Client::WorkflowHandle] A workflow handle to the started/existing workflow.
    #
    # @raise [Temporal::Error::RPCError] Workflow could not be started.
    def start_workflow( # rubocop:disable Metrics/ParameterLists
      workflow,
      *args,
      id:,
      task_queue:,
      execution_timeout: nil,
      run_timeout: nil,
      task_timeout: nil,
      id_reuse_policy: Workflow::IDReusePolicy::ALLOW_DUPLICATE,
      retry_policy: nil,
      cron_schedule: '',
      memo: nil,
      search_attributes: nil,
      start_signal: nil,
      start_signal_args: [],
      rpc_metadata: {},
      rpc_timeout: nil
    )
      input = Interceptor::Client::StartWorkflowInput.new(
        workflow: workflow,
        args: args,
        id: id,
        task_queue: task_queue,
        execution_timeout: execution_timeout,
        run_timeout: run_timeout,
        task_timeout: task_timeout,
        id_reuse_policy: id_reuse_policy,
        retry_policy: retry_policy,
        cron_schedule: cron_schedule,
        memo: memo,
        search_attributes: search_attributes,
        headers: {},
        start_signal: start_signal,
        start_signal_args: start_signal_args,
        rpc_metadata: rpc_metadata,
        rpc_timeout: rpc_timeout,
      )

      implementation.start_workflow(input)
    end

    # Get a workflow handle to an existing workflow by its ID.
    #
    # @param id [String] Workflow ID to get a handle to.
    # @param run_id [String, nil] Run ID that will be used for all calls. If omitted, the latest run
    #   for a given workflow ID will be referenced.
    # @param first_execution_run_id [String, nil] A run ID referencing the first workflow execution
    #   in a chain. Workflows are chained when using continue-as-new, retries (as permitted by the
    #   retry policy) or cron executions.
    #
    # @return [Temporal::Client::WorkflowHandle] The workflow handle.
    def workflow_handle(id, run_id: nil, first_execution_run_id: nil)
      WorkflowHandle.new(
        implementation,
        id,
        run_id: run_id,
        result_run_id: run_id,
        first_execution_run_id: first_execution_run_id,
      )
    end

    private

    attr_reader :implementation
  end
end
