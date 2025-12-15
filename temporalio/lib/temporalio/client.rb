# frozen_string_literal: true

require 'google/protobuf/well_known_types'
require 'logger'
require 'temporalio/api'
require 'temporalio/client/async_activity_handle'
require 'temporalio/client/connection'
require 'temporalio/client/interceptor'
require 'temporalio/client/plugin'
require 'temporalio/client/schedule'
require 'temporalio/client/schedule_handle'
require 'temporalio/client/with_start_workflow_operation'
require 'temporalio/client/workflow_execution'
require 'temporalio/client/workflow_execution_count'
require 'temporalio/client/workflow_handle'
require 'temporalio/client/workflow_query_reject_condition'
require 'temporalio/client/workflow_update_handle'
require 'temporalio/client/workflow_update_wait_stage'
require 'temporalio/common_enums'
require 'temporalio/converters'
require 'temporalio/error'
require 'temporalio/internal/client/implementation'
require 'temporalio/priority'
require 'temporalio/retry_policy'
require 'temporalio/runtime'
require 'temporalio/search_attributes'
require 'temporalio/versioning_override'
require 'temporalio/workflow/definition'

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
    Options = Data.define(
      :connection,
      :namespace,
      :data_converter,
      :plugins,
      :interceptors,
      :logger,
      :default_workflow_query_reject_condition
    )

    # Options as returned from {options} for +**to_h+ splat use in {initialize}. See {initialize} for details.
    class Options; end # rubocop:disable Lint/EmptyClass

    ListWorkflowPage = Data.define(:executions, :next_page_token)

    # A page of workflow executions returned by {Client#list_workflow_page}.
    #
    # @!attribute executions
    #   @return [Array<WorkflowExecution>] List of workflow executions in this page.
    # @!attribute next_page_token
    #   @return [String, nil] Token for the next page of results. nil if there are no more results.
    class ListWorkflowPage; end # rubocop:disable Lint/EmptyClass

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
    # @param plugins [Array<Plugin>] Plugins to use for configuring clients and intercepting connection. Any plugins
    #   that also include {Worker::Plugin} will automatically be applied to the worker and should not be configured
    #   explicitly on the worker. WARNING: Plugins are experimental.
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
      tls: nil,
      data_converter: Converters::DataConverter.default,
      plugins: [],
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
      # Prepare connection. The connection var is needed here so it can be used in callback for plugin.
      base_connection = nil
      final_connection = nil
      around_connect = if plugins.any?
                         _validate_plugins!(plugins)
                         # For plugins, we have to do an around_connect approach with Connection where we provide a
                         # no-return-value proc that is invoked with the built options and yields newly built options.
                         # The connection will have been created before, but we allow plugins to return a
                         # different/extended connection, possibly avoiding actual connection altogether.
                         proc do |options, &block|
                           # Steep simply can't comprehend these advanced inline procs
                           # steep:ignore:start

                           # Root next call
                           next_call_called = false
                           next_call = proc do |options|
                             raise 'next_call called more than once' if next_call_called

                             next_call_called = true
                             block&.call(options)
                             base_connection
                           end
                           # Go backwards, building up new next_call invocations on plugins
                           next_call = plugins.reverse_each.reduce(next_call) do |next_call, plugin|
                             proc { |options| plugin.connect_client(options, next_call) }
                           end
                           # Do call
                           final_connection = next_call.call(options)

                           # steep:ignore:end
                         end
                       end
      # Now create connection
      base_connection = Connection.new(
        target_host:,
        api_key:,
        tls:,
        rpc_metadata:,
        rpc_retry:,
        identity:,
        keep_alive:,
        http_connect_proxy:,
        runtime:,
        lazy_connect:,
        around_connect: # steep:ignore
      )

      # Create client
      Client.new(
        connection: final_connection || base_connection,
        namespace:,
        data_converter:,
        plugins:,
        interceptors:,
        logger:,
        default_workflow_query_reject_condition:
      )
    end

    # @!visibility private
    def self._validate_plugins!(plugins)
      plugins.each do |plugin|
        raise ArgumentError, "#{plugin.class} does not implement Client::Plugin" unless plugin.is_a?(Plugin)

        # Validate plugin has implemented expected methods
        missing = Plugin.instance_methods(false).select { |m| plugin.method(m).owner == Plugin }
        unless missing.empty?
          raise ArgumentError, "#{plugin.class} missing the following client plugin method(s): #{missing.join(', ')}"
        end
      end
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
    # @param plugins [Array<Plugin>] Plugins to use for configuring clients. Any plugins that also include
    #   {Worker::Plugin} will automatically be applied to the worker and should not be configured explicitly on the
    #   worker. WARNING: Plugins are experimental.
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
      plugins: [],
      interceptors: [],
      logger: Logger.new($stdout, level: Logger::WARN),
      default_workflow_query_reject_condition: nil
    )
      @options = Options.new(
        connection:,
        namespace:,
        data_converter:,
        plugins:,
        interceptors:,
        logger:,
        default_workflow_query_reject_condition:
      ).freeze

      # Apply plugins
      Client._validate_plugins!(plugins)
      @options = plugins.reduce(@options) { |options, plugin| plugin.configure_client(options) }

      # Initialize interceptors
      @impl = @options.interceptors.reverse_each.reduce(
        Internal::Client::Implementation.new(self)
      ) do |acc, int| # steep:ignore
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
    # @param workflow [Class<Workflow::Definition>, String, Symbol] Workflow definition class or workflow name.
    # @param args [Array<Object>] Arguments to the workflow.
    # @param id [String] Unique identifier for the workflow execution.
    # @param task_queue [String] Task queue to run the workflow on.
    # @param static_summary [String, nil] Fixed single-line summary for this workflow execution that may appear in
    #   CLI/UI. This can be in single-line Temporal markdown format. This is currently experimental.
    # @param static_details [String, nil] Fixed details for this workflow execution that may appear in CLI/UI. This can
    #   be in Temporal markdown format and can be multiple lines. This is a fixed value on the workflow that cannot be
    #   updated. For details that can be updated, use {Workflow.current_details=} within the workflow. This is currently
    #   experimental.
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
    # @param memo [Hash{String, Symbol => Object}, nil] Memo for the workflow.
    # @param search_attributes [SearchAttributes, nil] Search attributes for the workflow.
    # @param start_delay [Float, nil] Amount of time in seconds to wait before starting the workflow. This does not work
    #   with `cron_schedule`.
    # @param request_eager_start [Boolean] Potentially reduce the latency to start this workflow by encouraging the
    #   server to start it on a local worker running with this same client. This is currently experimental.
    # @param versioning_override [VersioningOverride, nil] Override the version of the workflow.
    #   This is currently experimental.
    # @param priority [Priority] Priority of the workflow. This is currently experimental.
    # @param arg_hints [Array<Object>, nil] Overrides converter hints for arguments if any. If unset/nil and the
    #   workflow definition has arg hints, those are used by default.
    # @param result_hint [Object, nil] Overrides converter hint for result if any. If unset/nil and the workflow
    #   definition has result hint, it is used by default.
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
      static_summary: nil,
      static_details: nil,
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
      versioning_override: nil,
      priority: Priority.default,
      arg_hints: nil,
      result_hint: nil,
      rpc_options: nil
    )
      # Take hints from definition if there is a definition
      workflow, defn_arg_hints, defn_result_hint =
        Workflow::Definition._workflow_type_and_hints_from_workflow_parameter(workflow)
      @impl.start_workflow(Interceptor::StartWorkflowInput.new(
                             workflow:,
                             args:,
                             workflow_id: id,
                             task_queue:,
                             static_summary:,
                             static_details:,
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
                             versioning_override:,
                             priority:,
                             arg_hints: arg_hints || defn_arg_hints,
                             result_hint: result_hint || defn_result_hint,
                             rpc_options:
                           ))
    end

    # Start a workflow and wait for its result. This is a shortcut for {start_workflow} + {WorkflowHandle.result}.
    #
    # @param workflow [Class<Workflow::Definition>, Symbol, String] Workflow definition class or workflow name.
    # @param args [Array<Object>] Arguments to the workflow.
    # @param id [String] Unique identifier for the workflow execution.
    # @param task_queue [String] Task queue to run the workflow on.
    # @param static_summary [String, nil] Fixed single-line summary for this workflow execution that may appear in
    #   CLI/UI. This can be in single-line Temporal markdown format. This is currently experimental.
    # @param static_details [String, nil] Fixed details for this workflow execution that may appear in CLI/UI. This can
    #   be in Temporal markdown format and can be multiple lines. This is a fixed value on the workflow that cannot be
    #   updated. For details that can be updated, use {Workflow.current_details=} within the workflow. This is currently
    #   experimental.
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
    # @param memo [Hash{String, Symbol => Object}, nil] Memo for the workflow.
    # @param search_attributes [SearchAttributes, nil] Search attributes for the workflow.
    # @param start_delay [Float, nil] Amount of time in seconds to wait before starting the workflow. This does not work
    #   with `cron_schedule`.
    # @param request_eager_start [Boolean] Potentially reduce the latency to start this workflow by encouraging the
    #   server to start it on a local worker running with this same client. This is currently experimental.
    # @param versioning_override [VersioningOverride, nil] Override the version of the workflow.
    #   This is currently experimental.
    # @param priority [Priority] Priority for the workflow. This is currently experimental.
    # @param arg_hints [Array<Object>, nil] Overrides converter hints for arguments if any. If unset/nil and the
    #   workflow definition has arg hints, those are used by default.
    # @param result_hint [Object, nil] Overrides converter hint for result if any. If unset/nil and the workflow
    #   definition has result hint, it is used by default.
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
      static_summary: nil,
      static_details: nil,
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
      versioning_override: nil,
      priority: Priority.default,
      arg_hints: nil,
      result_hint: nil,
      rpc_options: nil
    )
      start_workflow(
        workflow,
        *args,
        id:,
        task_queue:,
        static_summary:,
        static_details:,
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
        versioning_override:,
        priority:,
        arg_hints:,
        result_hint:,
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
    # @param result_hint [Object, nil] Converter hint for the workflow's result.
    #
    # @return [WorkflowHandle] The workflow handle.
    def workflow_handle(
      workflow_id,
      run_id: nil,
      first_execution_run_id: nil,
      result_hint: nil
    )
      WorkflowHandle.new(
        client: self, id: workflow_id, run_id:, result_run_id: run_id, first_execution_run_id:, result_hint:
      )
    end

    # Start an update, possibly starting the workflow at the same time if it doesn't exist (depending upon ID conflict
    # policy). Note that in some cases this may fail but the workflow will still be started, and the handle can then be
    # retrieved on the start workflow operation.
    #
    # @param update [Workflow::Definition::Update, Symbol, String] Update definition or name.
    # @param args [Array<Object>] Update arguments.
    # @param start_workflow_operation [WithStartWorkflowOperation] Required with-start workflow operation. This must
    #   have an `id_conflict_policy` set.
    # @param wait_for_stage [WorkflowUpdateWaitStage] Required stage to wait until returning. ADMITTED is not
    #   currently supported. See https://docs.temporal.io/workflows#update for more details.
    # @param id [String] ID of the update.
    # @param arg_hints [Array<Object>, nil] Overrides converter hints for update arguments if any. If unset/nil and the
    #   update definition has arg hints, those are used by default.
    # @param result_hint [Object, nil] Overrides converter hint for update result if any. If unset/nil and the update
    #   definition has result hint, it is used by default.
    # @param rpc_options [RPCOptions, nil] Advanced RPC options.
    #
    # @return [WorkflowUpdateHandle] The update handle.
    # @raise [Error::WorkflowAlreadyStartedError] Workflow already exists and conflict/reuse policy does not allow.
    # @raise [Error::WorkflowUpdateRPCTimeoutOrCanceledError] This update call timed out or was canceled. This doesn't
    #   mean the update itself was timed out or canceled, and this doesn't mean the workflow did not start.
    # @raise [Error::RPCError] RPC error from call.
    def start_update_with_start_workflow(
      update,
      *args,
      start_workflow_operation:,
      wait_for_stage:,
      id: SecureRandom.uuid,
      arg_hints: nil,
      result_hint: nil,
      rpc_options: nil
    )
      update, defn_arg_hints, defn_result_hint = Workflow::Definition::Update._name_and_hints_from_parameter(update)
      @impl.start_update_with_start_workflow(
        Interceptor::StartUpdateWithStartWorkflowInput.new(
          update_id: id,
          update:,
          args:,
          wait_for_stage:,
          start_workflow_operation:,
          arg_hints: arg_hints || defn_arg_hints,
          result_hint: result_hint || defn_result_hint,
          headers: {},
          rpc_options:
        )
      )
    end

    # Start an update, possibly starting the workflow at the same time if it doesn't exist (depending upon ID conflict
    # policy), and wait for update result. This is a shortcut for {start_update_with_start_workflow} +
    # {WorkflowUpdateHandle.result}.
    #
    # @param update [Workflow::Definition::Update, Symbol, String] Update definition or name.
    # @param args [Array<Object>] Update arguments.
    # @param start_workflow_operation [WithStartWorkflowOperation] Required with-start workflow operation. This must
    #   have an `id_conflict_policy` set.
    # @param id [String] ID of the update.
    # @param arg_hints [Array<Object>, nil] Overrides converter hints for update arguments if any. If unset/nil and the
    #   update definition has arg hints, those are used by default.
    # @param result_hint [Object, nil] Overrides converter hint for update result if any. If unset/nil and the update
    #   definition has result hint, it is used by default.
    # @param rpc_options [RPCOptions, nil] Advanced RPC options.
    #
    # @return [Object] Successful update result.
    # @raise [Error::WorkflowUpdateFailedError] If the update failed.
    # @raise [Error::WorkflowAlreadyStartedError] Workflow already exists and conflict/reuse policy does not allow.
    # @raise [Error::WorkflowUpdateRPCTimeoutOrCanceledError] This update call timed out or was canceled. This doesn't
    #   mean the update itself was timed out or canceled, and this doesn't mean the workflow did not start.
    # @raise [Error::RPCError] RPC error from call.
    def execute_update_with_start_workflow(
      update,
      *args,
      start_workflow_operation:,
      id: SecureRandom.uuid,
      arg_hints: nil,
      result_hint: nil,
      rpc_options: nil
    )
      start_update_with_start_workflow(
        update,
        *args,
        start_workflow_operation:,
        wait_for_stage: WorkflowUpdateWaitStage::COMPLETED,
        id:,
        arg_hints:,
        result_hint:,
        rpc_options:
      ).result
    end

    # Send a signal, possibly starting the workflow at the same time if it doesn't exist.
    #
    # @param signal [Workflow::Definition::Signal, Symbol, String] Signal definition or name.
    # @param args [Array<Object>] Signal arguments.
    # @param start_workflow_operation [WithStartWorkflowOperation] Required with-start workflow operation. This may not
    #   support all `id_conflict_policy` options.
    # @param arg_hints [Array<Object>, nil] Overrides converter hints for signal arguments if any. If unset/nil and the
    #   signal definition has arg hints, those are used by default.
    # @param rpc_options [RPCOptions, nil] Advanced RPC options.
    #
    # @return [WorkflowHandle] A workflow handle to the workflow.
    # @raise [Error::WorkflowAlreadyStartedError] Workflow already exists and conflict/reuse policy does not allow.
    # @raise [Error::RPCError] RPC error from call.
    def signal_with_start_workflow(
      signal,
      *args,
      start_workflow_operation:,
      arg_hints: nil,
      rpc_options: nil
    )
      signal, defn_arg_hints = Workflow::Definition::Signal._name_and_hints_from_parameter(signal)
      @impl.signal_with_start_workflow(
        Interceptor::SignalWithStartWorkflowInput.new(
          signal:,
          args:,
          start_workflow_operation:,
          arg_hints: arg_hints || defn_arg_hints,
          rpc_options:
        )
      )
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
      next_page_token = nil
      Enumerator.new do |yielder|
        loop do
          list_workflow_page_input = Interceptor::ListWorkflowPageInput.new(
            query: query,
            rpc_options: rpc_options,
            next_page_token: next_page_token,
            page_size: nil
          )
          page = @impl.list_workflow_page(list_workflow_page_input)
          page.executions.each { |execution| yielder << execution }
          next_page_token = page.next_page_token
          break if (next_page_token || '').empty?
        end
      end
    end

    # List workflows one page at a time.
    #
    # @param query [String, nil] A Temporal visibility list filter.
    # @param page_size [Integer, nil] Maximum number of results to return.
    # @param next_page_token [String, nil] Token for the next page of results. If not set, the first page is returned.
    # @param rpc_options [RPCOptions, nil] Advanced RPC options.
    #
    # @return [ListWorkflowPage] Page of workflow executions, along with a next_page_token to keep fetching.
    #
    # @raise [Error::RPCError] RPC error from call.
    #
    # @see https://docs.temporal.io/visibility
    def list_workflow_page(query = nil, page_size: nil, next_page_token: nil, rpc_options: nil)
      @impl.list_workflow_page(Interceptor::ListWorkflowPageInput.new(query:,
                                                                      next_page_token:,
                                                                      page_size:,
                                                                      rpc_options:))
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

    # Create a schedule and return its handle.
    #
    # @param id [String] Unique identifier of the schedule.
    # @param schedule [Schedule] Schedule to create.
    # @param trigger_immediately [Boolean]  If true, trigger one action immediately when creating the schedule.
    # @param backfills [Array<Schedule::Backfill>] Set of time periods to take actions on as if that time passed right
    #   now.
    # @param memo [Hash<String, Object>, nil] Memo for the schedule. Memo for a scheduled workflow is part of the
    #   schedule action.
    # @param search_attributes [SearchAttributes, nil] Search attributes for the schedule. Search attributes for a
    #   scheduled workflow are part of the scheduled action.
    # @param rpc_options [RPCOptions, nil] Advanced RPC options.
    #
    # @return [ScheduleHandle] A handle to the created schedule.
    # @raise [Error::ScheduleAlreadyRunningError] If a schedule with this ID is already running.
    # @raise [Error::RPCError] RPC error from call.
    def create_schedule(
      id,
      schedule,
      trigger_immediately: false,
      backfills: [],
      memo: nil,
      search_attributes: nil,
      rpc_options: nil
    )
      @impl.create_schedule(Interceptor::CreateScheduleInput.new(
                              id:,
                              schedule:,
                              trigger_immediately:,
                              backfills:,
                              memo:,
                              search_attributes:,
                              rpc_options:
                            ))
    end

    # Get a schedule handle to an existing schedule for the given ID.
    #
    # @param id [String] Schedule ID to get a handle to.
    # @return [ScheduleHandle] The schedule handle.
    def schedule_handle(id)
      ScheduleHandle.new(client: self, id:)
    end

    # List schedules.
    #
    # Note, this list is eventually consistent. Therefore if a schedule is added or deleted, it may not be available in
    # the list immediately.
    #
    # @param query [String] A Temporal visibility list filter.
    # @param rpc_options [RPCOptions, nil] Advanced RPC options.
    #
    # @return [Enumerator<Schedule::List::Description>] Enumerable schedules.
    #
    # @raise [Error::RPCError] RPC error from call.
    #
    # @see https://docs.temporal.io/visibility
    def list_schedules(query = nil, rpc_options: nil)
      @impl.list_schedules(Interceptor::ListSchedulesInput.new(query:, rpc_options:))
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
