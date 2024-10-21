# frozen_string_literal: true

require 'google/protobuf/well_known_types'
require 'logger'
require 'temporalio/api'
require 'temporalio/client/async_activity_handle'
require 'temporalio/client/connection'
require 'temporalio/client/interceptor'
require 'temporalio/client/workflow_execution'
require 'temporalio/client/workflow_execution_count'
require 'temporalio/client/workflow_handle'
require 'temporalio/client/workflow_query_reject_condition'
require 'temporalio/common_enums'
require 'temporalio/converters'
require 'temporalio/error'
require 'temporalio/internal/client/implementation'
require 'temporalio/retry_policy'
require 'temporalio/runtime'
require 'temporalio/search_attributes'

module Temporalio
  # Client for accessing Temporal.
  #
  # Most users will use {connect} to connect a client. The {workflow_service} method provides access to a raw gRPC
  # client. To create another client on the same connection, like for a different namespace, {options} may be used to
  # get the options as a struct which can then be dup'd, altered, and splatted as kwargs to the constructor (e.g.
  # +Client.new(**my_options.to_h)+).
  #
  # Clients are thread-safe and are meant to be reused for the life of the application. They are built to work in both
  # synchronous and asynchronous contexts. Internally they use callbacks based on {::Queue} which means they are
  # Fiber-compatible.
  class Client
    # Options as returned from {options} for +**to_h+ splat use in {initialize}. See {initialize} for details.
    Options = Struct.new(
      :connection,
      :namespace,
      :data_converter,
      :interceptors,
      :logger,
      :default_workflow_query_reject_condition,
      keyword_init: true
    )

    # Connect to Temporal server. This is a shortcut for +Connection.new+ followed by +Client.new+.
    #
    # @param target_host [String] +host:port+ for the Temporal server. For local development, this is often
    #   +localhost:7233+.
    # @param namespace [String] Namespace to use for client calls.
    # @param api_key [String, nil] API key for Temporal. This becomes the +Authorization+ HTTP header with +"Bearer "+
    #   prepended. This is only set if RPC metadata doesn't already have an +authorization+ key.
    # @param tls [Boolean, Connection::TLSOptions] If false, do not use TLS. If true, use system default TLS options. If
    #   TLS options are present, those TLS options will be used.
    # @param data_converter [Converters::DataConverter] Data converter to use for all data conversions to/from payloads.
    # @param interceptors [Array<Interceptor>] Set of interceptors that are chained together to allow intercepting of
    #   client calls. The earlier interceptors wrap the later ones. Any interceptors that also implement worker
    #   interceptor will be used as worker interceptors too so they should not be given separately when creating a
    #   worker.
    # @param logger [Logger] Logger to use for this client and any workers made from this client. Defaults to stdout
    #   with warn level. Callers setting this logger are responsible for closing it.
    # @param default_workflow_query_reject_condition [WorkflowQueryRejectCondition, nil] Default rejection
    #   condition for workflow queries if not set during query. See {WorkflowHandle.query} for details on the
    #   rejection condition.
    # @param rpc_metadata [Hash<String, String>] Headers to use for all calls to the server. Keys here can be overriden
    #   by per-call RPC metadata keys.
    # @param rpc_retry [Connection::RPCRetryOptions] Retry options for direct service calls (when opted in) or all
    #   high-level calls made by this client (which all opt-in to retries by default).
    # @param identity [String] Identity for this client.
    # @param keep_alive [Connection::KeepAliveOptions] Keep-alive options for the client connection. Can be set to +nil+
    #   to disable.
    # @param http_connect_proxy [Connection::HTTPConnectProxyOptions, nil] Options for HTTP CONNECT proxy.
    # @param runtime [Runtime] Runtime for this client.
    # @param lazy_connect [Boolean] If true, the client will not connect until the first call is attempted or a worker
    #   is created with it. Lazy clients cannot be used for workers if they have not performed a connection.
    #
    # @return [Client] Connected client.
    #
    # @see Connection.initialize
    # @see initialize
    def self.connect(
      target_host,
      namespace,
      api_key: nil,
      tls: false,
      data_converter: Converters::DataConverter.default,
      interceptors: [],
      logger: Logger.new($stdout, level: Logger::WARN),
      default_workflow_query_reject_condition: nil,
      rpc_metadata: {},
      rpc_retry: Connection::RPCRetryOptions.new,
      identity: "#{Process.pid}@#{Socket.gethostname}",
      keep_alive: Connection::KeepAliveOptions.new, # Set to nil to disable
      http_connect_proxy: nil,
      runtime: Runtime.default,
      lazy_connect: false
    )
      Client.new(
        connection: Connection.new(
          target_host:,
          api_key:,
          tls:,
          rpc_metadata:,
          rpc_retry:,
          identity:,
          keep_alive:,
          http_connect_proxy:,
          runtime:,
          lazy_connect:
        ),
        namespace:,
        data_converter:,
        interceptors:,
        logger:,
        default_workflow_query_reject_condition:
      )
    end

    # @return [Options] Frozen options for this client which has the same attributes as {initialize}.
    attr_reader :options

    # Create a client from an existing connection. Most users will prefer {connect} instead. Parameters here match
    # {Options} returned from {options} by intention so options can be dup'd, altered, and splatted to create a new
    # client.
    #
    # @param connection [Connection] Existing connection to create a client from.
    # @param namespace [String] Namespace to use for client calls.
    # @param data_converter [Converters::DataConverter] Data converter to use for all data conversions to/from payloads.
    # @param interceptors [Array<Interceptor>] Set of interceptors that are chained together to allow intercepting of
    #   client calls. The earlier interceptors wrap the later ones. Any interceptors that also implement worker
    #   interceptor will be used as worker interceptors too so they should not be given separately when creating a
    #   worker.
    # @param logger [Logger] Logger to use for this client and any workers made from this client. Defaults to stdout
    #   with warn level. Callers setting this logger are responsible for closing it.
    # @param default_workflow_query_reject_condition [WorkflowQueryRejectCondition, nil] Default rejection condition for
    #   workflow queries if not set during query. See {WorkflowHandle.query} for details on the rejection condition.
    #
    # @see connect
    def initialize(
      connection:,
      namespace:,
      data_converter: DataConverter.default,
      interceptors: [],
      logger: Logger.new($stdout, level: Logger::WARN),
      default_workflow_query_reject_condition: nil
    )
      @options = Options.new(
        connection:,
        namespace:,
        data_converter:,
        interceptors:,
        logger:,
        default_workflow_query_reject_condition:
      ).freeze
      # Initialize interceptors
      @impl = interceptors.reverse_each.reduce(Internal::Client::Implementation.new(self)) do |acc, int|
        int.intercept_client(acc)
      end
    end

    # @return [Connection] Underlying connection for this client.
    def connection
      @options.connection
    end

    # @return [String] Namespace used in calls by this client.
    def namespace
      @options.namespace
    end

    # @return [DataConverter] Data converter used by this client.
    def data_converter
      @options.data_converter
    end

    # @return [Connection::WorkflowService] Raw gRPC workflow service.
    def workflow_service
      connection.workflow_service
    end

    # @return [Connection::OperatorService] Raw gRPC operator service.
    def operator_service
      connection.operator_service
    end

    # Start a workflow and return its handle.
    #
    # @param workflow [Workflow, String] Name of the workflow
    # @param args [Array<Object>] Arguments to the workflow.
    # @param id [String] Unique identifier for the workflow execution.
    # @param task_queue [String] Task queue to run the workflow on.
    # @param execution_timeout [Float, nil] Total workflow execution timeout in seconds including retries and continue
    #   as new.
    # @param run_timeout [Float, nil] Timeout of a single workflow run in seconds.
    # @param task_timeout [Float, nil] Timeout of a single workflow task in seconds.
    # @param id_reuse_policy [WorkflowIDReusePolicy] How already-existing IDs are treated.
    # @param id_conflict_policy [WorkflowIDConflictPolicy] How already-running workflows of the same ID are treated.
    #   Default is unspecified which effectively means fail the start attempt. This cannot be set if `id_reuse_policy`
    #   is set to terminate if running.
    # @param retry_policy [RetryPolicy, nil] Retry policy for the workflow.
    # @param cron_schedule [String, nil] Cron schedule. Users should use schedules instead of this.
    # @param memo [Hash<String, Object>, nil] Memo for the workflow.
    # @param search_attributes [SearchAttributes, nil] Search attributes for the workflow.
    # @param start_delay [Float, nil] Amount of time in seconds to wait before starting the workflow. This does not work
    #   with `cron_schedule`.
    # @param request_eager_start [Boolean] Potentially reduce the latency to start this workflow by encouraging the
    #   server to start it on a local worker running with this same client. This is currently experimental.
    # @param rpc_options [RPCOptions, nil] Advanced RPC options.
    #
    # @return [WorkflowHandle] A workflow handle to the started workflow.
    # @raise [Error::WorkflowAlreadyStartedError] Workflow already exists.
    # @raise [Error::RPCError] RPC error from call.
    def start_workflow(
      workflow,
      *args,
      id:,
      task_queue:,
      execution_timeout: nil,
      run_timeout: nil,
      task_timeout: nil,
      id_reuse_policy: WorkflowIDReusePolicy::ALLOW_DUPLICATE,
      id_conflict_policy: WorkflowIDConflictPolicy::UNSPECIFIED,
      retry_policy: nil,
      cron_schedule: nil,
      memo: nil,
      search_attributes: nil,
      start_delay: nil,
      request_eager_start: false,
      rpc_options: nil
    )
      @impl.start_workflow(Interceptor::StartWorkflowInput.new(
                             workflow:,
                             args:,
                             workflow_id: id,
                             task_queue:,
                             execution_timeout:,
                             run_timeout:,
                             task_timeout:,
                             id_reuse_policy:,
                             id_conflict_policy:,
                             retry_policy:,
                             cron_schedule:,
                             memo:,
                             search_attributes:,
                             start_delay:,
                             request_eager_start:,
                             headers: {},
                             rpc_options:
                           ))
    end

    # Start a workflow and wait for its result. This is a shortcut for {start_workflow} + {WorkflowHandle.result}.
    #
    # @param workflow [Workflow, String] Name of the workflow
    # @param args [Array<Object>] Arguments to the workflow.
    # @param id [String] Unique identifier for the workflow execution.
    # @param task_queue [String] Task queue to run the workflow on.
    # @param execution_timeout [Float, nil] Total workflow execution timeout in seconds including retries and continue
    #   as new.
    # @param run_timeout [Float, nil] Timeout of a single workflow run in seconds.
    # @param task_timeout [Float, nil] Timeout of a single workflow task in seconds.
    # @param id_reuse_policy [WorkflowIDReusePolicy] How already-existing IDs are treated.
    # @param id_conflict_policy [WorkflowIDConflictPolicy] How already-running workflows of the same ID are treated.
    #   Default is unspecified which effectively means fail the start attempt. This cannot be set if `id_reuse_policy`
    #   is set to terminate if running.
    # @param retry_policy [RetryPolicy, nil] Retry policy for the workflow.
    # @param cron_schedule [String, nil] Cron schedule. Users should use schedules instead of this.
    # @param memo [Hash<String, Object>, nil] Memo for the workflow.
    # @param search_attributes [SearchAttributes, nil] Search attributes for the workflow.
    # @param start_delay [Float, nil] Amount of time in seconds to wait before starting the workflow. This does not work
    #   with `cron_schedule`.
    # @param request_eager_start [Boolean] Potentially reduce the latency to start this workflow by encouraging the
    #   server to start it on a local worker running with this same client. This is currently experimental.
    # @param rpc_options [RPCOptions, nil] Advanced RPC options.
    #
    # @return [Object] Successful result of the workflow.
    # @raise [Error::WorkflowAlreadyStartedError] Workflow already exists.
    # @raise [Error::WorkflowFailedError] Workflow failed with +cause+ as the cause.
    # @raise [Error::RPCError] RPC error from call.
    def execute_workflow(
      workflow,
      *args,
      id:,
      task_queue:,
      execution_timeout: nil,
      run_timeout: nil,
      task_timeout: nil,
      id_reuse_policy: WorkflowIDReusePolicy::ALLOW_DUPLICATE,
      id_conflict_policy: WorkflowIDConflictPolicy::UNSPECIFIED,
      retry_policy: nil,
      cron_schedule: nil,
      memo: nil,
      search_attributes: nil,
      start_delay: nil,
      request_eager_start: false,
      rpc_options: nil
    )
      start_workflow(
        workflow,
        *args,
        id:,
        task_queue:,
        execution_timeout:,
        run_timeout:,
        task_timeout:,
        id_reuse_policy:,
        id_conflict_policy:,
        retry_policy:,
        cron_schedule:,
        memo:,
        search_attributes:,
        start_delay:,
        request_eager_start:,
        rpc_options:
      ).result
    end

    # Get a workflow handle to an existing workflow by its ID.
    #
    # @param workflow_id [String] Workflow ID to get a handle to.
    # @param run_id [String, nil] Run ID that will be used for all calls. Many choose to leave this unset which ensures
    #   interactions occur on the latest of the workflow ID.
    # @param first_execution_run_id [String, nil] First execution run ID used for some calls like cancellation and
    #   termination to ensure the affected workflow is only within the same chain as this given run ID.
    #
    # @return [WorkflowHandle] The workflow handle.
    def workflow_handle(
      workflow_id,
      run_id: nil,
      first_execution_run_id: nil
    )
      WorkflowHandle.new(client: self, id: workflow_id, run_id:, result_run_id: run_id, first_execution_run_id:)
    end

    # List workflows.
    #
    # @param query [String, nil] A Temporal visibility list filter.
    # @param rpc_options [RPCOptions, nil] Advanced RPC options.
    #
    # @return [Enumerator<WorkflowExecution>] Enumerable workflow executions.
    #
    # @raise [Error::RPCError] RPC error from call.
    #
    # @see https://docs.temporal.io/visibility
    def list_workflows(query = nil, rpc_options: nil)
      @impl.list_workflows(Interceptor::ListWorkflowsInput.new(query:, rpc_options:))
    end

    # Count workflows.
    #
    # @param query [String, nil] A Temporal visibility list filter.
    # @param rpc_options [RPCOptions, nil] Advanced RPC options.
    #
    # @return [WorkflowExecutionCount] Count of workflows.
    #
    # @raise [Error::RPCError] RPC error from call.
    #
    # @see https://docs.temporal.io/visibility
    def count_workflows(query = nil, rpc_options: nil)
      @impl.count_workflows(Interceptor::CountWorkflowsInput.new(query:, rpc_options:))
    end

    # Get an async activity handle.
    #
    # @param task_token_or_id_reference [String, ActivityIDReference] Task token string or activity ID reference.
    # @return [AsyncActivityHandle]
    def async_activity_handle(task_token_or_id_reference)
      if task_token_or_id_reference.is_a?(ActivityIDReference)
        AsyncActivityHandle.new(client: self, task_token: nil, id_reference: task_token_or_id_reference)
      elsif task_token_or_id_reference.is_a?(String)
        AsyncActivityHandle.new(client: self, task_token: task_token_or_id_reference, id_reference: nil)
      else
        raise ArgumentError, 'Must be a string task token or an ActivityIDReference'
      end
    end

    # @!visibility private
    def _impl
      @impl
    end

    # Set of RPC options for RPC calls.
    class RPCOptions
      # @return [Hash<String, String>, nil] Headers to include on the RPC call.
      attr_accessor :metadata

      # @return [Float, nil] Number of seconds before timeout of the RPC call.
      attr_accessor :timeout

      # @return [Cancellation, nil] Cancellation to use to potentially cancel the call. If canceled, the RPC will return
      #   {Error::CanceledError}.
      attr_accessor :cancellation

      # @return [Boolean, nil] Whether to override the default retry option which decides whether to retry calls
      #   implicitly when known transient error codes are reached. By default when this is nil, high-level calls retry
      #   known transient error codes and low-level/direct calls do not.
      attr_accessor :override_retry

      # Create RPC options.
      #
      # @param metadata [Hash<String, String>, nil] Headers to include on the RPC call.
      # @param timeout [Float, nil] Number of seconds before timeout of the RPC call.
      # @param cancellation [Cancellation, nil] Cancellation to use to potentially cancel the call. If canceled, the RPC
      #   will return {Error::CanceledError}.
      # @param override_retry [Boolean, nil] Whether to override the default retry option which decides whether to retry
      #   calls implicitly when known transient error codes are reached. By default when this is nil, high-level calls
      #   retry known transient error codes and low-level/direct calls do not.
      def initialize(
        metadata: nil,
        timeout: nil,
        cancellation: nil,
        override_retry: nil
      )
        @metadata = metadata
        @timeout = timeout
        @cancellation = cancellation
        @override_retry = override_retry
      end
    end
  end
end
