# frozen_string_literal: true

require 'google/protobuf/well_known_types'
require 'temporalio/api'
require 'temporalio/client/connection'
require 'temporalio/client/interceptor'
require 'temporalio/client/workflow_handle'
require 'temporalio/common_enums'
require 'temporalio/converters'
require 'temporalio/error'
require 'temporalio/internal/proto_utils'
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
    #   client calls. The earlier interceptors wrap the later ones. Any interceptors that also implement
    #   {Worker::Interceptor} will be used as worker interceptors too so they should not be given separately when
    #   creating a worker.
    # @param default_workflow_query_reject_condition [Api::Enums::V1::QueryRejectCondition, nil] Default rejection
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
    #   client calls. The earlier interceptors wrap the later ones.
    #
    #   Any interceptors that also implement {Worker::Interceptor} will be used as worker interceptors too so they
    #   should not be given separately when creating a worker.
    # @param default_workflow_query_reject_condition [Api::Enums::V1::QueryRejectCondition, nil] Default rejection
    #   condition for workflow queries if not set during query. See {WorkflowHandle.query} for details on the
    #   rejection condition.
    #
    # @see connect
    def initialize(
      connection:,
      namespace:,
      data_converter: DataConverter.default,
      interceptors: [],
      default_workflow_query_reject_condition: nil
    )
      @options = Options.new(
        connection:,
        namespace:,
        data_converter:,
        interceptors:,
        default_workflow_query_reject_condition:
      ).freeze
      # Initialize interceptors
      @impl = interceptors.reverse_each.reduce(Implementation.new(self)) do |acc, int|
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
    # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
    # @param rpc_timeout [Float, nil] Number of seconds before timeout.
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
      rpc_metadata: nil,
      rpc_timeout: nil
    )
      @impl.start_workflow(Interceptor::StartWorkflowInput.new(
                             workflow:,
                             args:,
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
                             headers: {},
                             rpc_metadata:,
                             rpc_timeout:
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
    # @param rpc_metadata [Hash<String, String>, nil] Headers to include on the RPC call.
    # @param rpc_timeout [Float, nil] Number of seconds before timeout.
    #
    # @return [Object] Successful result of the workflow.
    # @raise [Error::WorkflowAlreadyStartedError] Workflow already exists.
    # @raise [Error::WorkflowFailureError] Workflow failed with {Error::WorkflowFailureError.cause} as cause.
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
      rpc_metadata: nil,
      rpc_timeout: nil
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
        rpc_metadata:,
        rpc_timeout:
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
      WorkflowHandle.new(self, workflow_id, run_id:, result_run_id: run_id, first_execution_run_id:)
    end

    # @!visibility private
    def _impl
      @impl
    end

    # @!visibility private
    class Implementation < Interceptor::Outbound
      def initialize(client)
        super(nil)
        @client = client
      end

      # @!visibility private
      def start_workflow(input)
        # TODO(cretz): Signal/update with start
        req = Api::WorkflowService::V1::StartWorkflowExecutionRequest.new(
          request_id: SecureRandom.uuid,
          namespace: @client.namespace,
          workflow_type: Api::Common::V1::WorkflowType.new(name: input.workflow.to_s),
          workflow_id: input.id,
          task_queue: Api::TaskQueue::V1::TaskQueue.new(name: input.task_queue.to_s),
          input: @client.data_converter.to_payloads(input.args),
          workflow_execution_timeout: Internal::ProtoUtils.seconds_to_duration(input.execution_timeout),
          workflow_run_timeout: Internal::ProtoUtils.seconds_to_duration(input.run_timeout),
          workflow_task_timeout: Internal::ProtoUtils.seconds_to_duration(input.task_timeout),
          identity: @client.connection.identity,
          workflow_id_reuse_policy: input.id_reuse_policy,
          workflow_id_conflict_policy: input.id_conflict_policy,
          retry_policy: input.retry_policy&.to_proto,
          cron_schedule: input.cron_schedule,
          memo: Internal::ProtoUtils.memo_to_proto(input.memo, @client.data_converter),
          search_attributes: input.search_attributes&.to_proto,
          workflow_start_delay: Internal::ProtoUtils.seconds_to_duration(input.start_delay),
          request_eager_execution: input.request_eager_start,
          header: input.headers
        )

        # Send request
        begin
          resp = @client.workflow_service.start_workflow_execution(
            req,
            rpc_retry: true,
            rpc_metadata: input.rpc_metadata,
            rpc_timeout: input.rpc_timeout
          )
        rescue Error::RPCError => e
          # Unpack and raise already started if that's the error, otherwise default raise
          if e.code == Error::RPCError::Code::ALREADY_EXISTS && e.grpc_status.details.first
            details = e.grpc_status.details.first.unpack(Api::ErrorDetails::V1::WorkflowExecutionAlreadyStartedFailure)
            if details
              raise Error::WorkflowAlreadyStartedError.new(
                workflow_id: req.workflow_id,
                workflow_type: req.workflow_type.name,
                run_id: details.run_id
              )
            end
          end
          raise
        end

        # Return handle
        WorkflowHandle.new(
          @client,
          input.id,
          result_run_id: resp.run_id,
          first_execution_run_id: resp.run_id
        )
      end

      # @!visibility private
      def fetch_workflow_history_event_page(input)
        req = Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest.new(
          namespace: @client.namespace,
          execution: Api::Common::V1::WorkflowExecution.new(
            workflow_id: input.id,
            run_id: input.run_id || ''
          ),
          maximum_page_size: input.page_size || 0,
          next_page_token: input.next_page_token,
          wait_new_event: input.wait_new_event,
          history_event_filter_type: input.event_filter_type,
          skip_archival: input.skip_archival
        )
        resp = @client.workflow_service.get_workflow_execution_history(
          req,
          rpc_retry: true,
          rpc_metadata: input.rpc_metadata,
          rpc_timeout: input.rpc_timeout
        )
        Interceptor::FetchWorkflowHistoryEventPage.new(
          events: resp.history&.events || [],
          next_page_token: resp.next_page_token.empty? ? nil : resp.next_page_token
        )
      end
    end
  end
end
