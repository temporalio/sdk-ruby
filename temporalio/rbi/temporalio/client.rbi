# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::Client
  sig do
    params(
      connection: Temporalio::Client::Connection,
      namespace: String,
      data_converter: Temporalio::Converters::DataConverter,
      plugins: T::Array[Temporalio::Client::Plugin],
      interceptors: T::Array[Temporalio::Client::Interceptor],
      logger: ::Logger,
      default_workflow_query_reject_condition: T.nilable(Integer)
    ).void
  end
  def initialize(
    connection:,
    namespace:,
    data_converter: T.unsafe(nil),
    plugins: T.unsafe(nil),
    interceptors: T.unsafe(nil),
    logger: T.unsafe(nil),
    default_workflow_query_reject_condition: T.unsafe(nil)
  )
  end
  sig { returns(Temporalio::Client::Options) }
  attr_reader :options

  sig { returns(Temporalio::Client::Connection) }
  def connection; end

  sig { returns(String) }
  def namespace; end

  sig { returns(Temporalio::Converters::DataConverter) }
  def data_converter; end

  sig { returns(Temporalio::Client::Connection::WorkflowService) }
  def workflow_service; end

  sig { returns(Temporalio::Client::Connection::OperatorService) }
  def operator_service; end

  sig do
    params(
      workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol,
                      String),
      args: T.nilable(Object),
      id: String,
      task_queue: String,
      static_summary: T.nilable(String),
      static_details: T.nilable(String),
      execution_timeout: T.nilable(T.any(Integer, Float)),
      run_timeout: T.nilable(T.any(Integer, Float)),
      task_timeout: T.nilable(T.any(Integer, Float)),
      id_reuse_policy: Integer,
      id_conflict_policy: Integer,
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      cron_schedule: T.nilable(String),
      memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
      search_attributes: T.nilable(Temporalio::SearchAttributes),
      start_delay: T.nilable(T.any(Integer, Float)),
      request_eager_start: T::Boolean,
      versioning_override: T.nilable(Temporalio::VersioningOverride),
      priority: Temporalio::Priority,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowHandle)
  end
  def start_workflow(
    workflow,
    *args,
    id:,
    task_queue:,
    static_summary: T.unsafe(nil),
    static_details: T.unsafe(nil),
    execution_timeout: T.unsafe(nil),
    run_timeout: T.unsafe(nil),
    task_timeout: T.unsafe(nil),
    id_reuse_policy: T.unsafe(nil),
    id_conflict_policy: T.unsafe(nil),
    retry_policy: T.unsafe(nil),
    cron_schedule: T.unsafe(nil),
    memo: T.unsafe(nil),
    search_attributes: T.unsafe(nil),
    start_delay: T.unsafe(nil),
    request_eager_start: T.unsafe(nil),
    versioning_override: T.unsafe(nil),
    priority: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  )
  end
  sig do
    params(
      workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol,
                      String),
      args: T.nilable(Object),
      id: String,
      task_queue: String,
      static_summary: T.nilable(String),
      static_details: T.nilable(String),
      execution_timeout: T.nilable(T.any(Integer, Float)),
      run_timeout: T.nilable(T.any(Integer, Float)),
      task_timeout: T.nilable(T.any(Integer, Float)),
      id_reuse_policy: Integer,
      id_conflict_policy: Integer,
      retry_policy: T.nilable(Temporalio::RetryPolicy),
      cron_schedule: T.nilable(String),
      memo: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
      search_attributes: T.nilable(Temporalio::SearchAttributes),
      start_delay: T.nilable(T.any(Integer, Float)),
      request_eager_start: T::Boolean,
      versioning_override: T.nilable(Temporalio::VersioningOverride),
      priority: Temporalio::Priority,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def execute_workflow(
    workflow,
    *args,
    id:,
    task_queue:,
    static_summary: T.unsafe(nil),
    static_details: T.unsafe(nil),
    execution_timeout: T.unsafe(nil),
    run_timeout: T.unsafe(nil),
    task_timeout: T.unsafe(nil),
    id_reuse_policy: T.unsafe(nil),
    id_conflict_policy: T.unsafe(nil),
    retry_policy: T.unsafe(nil),
    cron_schedule: T.unsafe(nil),
    memo: T.unsafe(nil),
    search_attributes: T.unsafe(nil),
    start_delay: T.unsafe(nil),
    request_eager_start: T.unsafe(nil),
    versioning_override: T.unsafe(nil),
    priority: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  )
  end
  sig do
    params(
      workflow_id: String,
      run_id: T.nilable(String),
      first_execution_run_id: T.nilable(String),
      result_hint: T.nilable(Object)
    ).returns(Temporalio::Client::WorkflowHandle)
  end
  def workflow_handle(workflow_id, run_id: T.unsafe(nil), first_execution_run_id: T.unsafe(nil),
                      result_hint: T.unsafe(nil))
  end

  sig do
    params(
      update: T.any(Temporalio::Workflow::Definition::Update, Symbol, String),
      args: T.nilable(Object),
      start_workflow_operation: Temporalio::Client::WithStartWorkflowOperation,
      wait_for_stage: Integer,
      id: String,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowUpdateHandle)
  end
  def start_update_with_start_workflow(
    update,
    *args,
    start_workflow_operation:,
    wait_for_stage:,
    id: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  )
  end
  sig do
    params(
      update: T.any(Temporalio::Workflow::Definition::Update, Symbol, String),
      args: T.nilable(Object),
      start_workflow_operation: Temporalio::Client::WithStartWorkflowOperation,
      id: String,
      arg_hints: T.nilable(T::Array[Object]),
      result_hint: T.nilable(Object),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T.nilable(Object))
  end
  def execute_update_with_start_workflow(
    update,
    *args,
    start_workflow_operation:,
    id: T.unsafe(nil),
    arg_hints: T.unsafe(nil),
    result_hint: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  )
  end
  sig do
    params(
      signal: T.any(Temporalio::Workflow::Definition::Signal, Symbol, String),
      args: T.nilable(Object),
      start_workflow_operation: Temporalio::Client::WithStartWorkflowOperation,
      arg_hints: T.nilable(T::Array[Object]),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowHandle)
  end
  def signal_with_start_workflow(
    signal,
    *args,
    start_workflow_operation:,
    arg_hints: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  )
  end
  sig do
    params(
      query: T.nilable(String),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T::Enumerator[Temporalio::Client::WorkflowExecution])
  end
  def list_workflows(query = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      query: T.nilable(String),
      page_size: T.nilable(Integer),
      next_page_token: T.nilable(String),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::ListWorkflowPage)
  end
  def list_workflow_page(query = T.unsafe(nil), page_size: T.unsafe(nil), next_page_token: T.unsafe(nil),
                         rpc_options: T.unsafe(nil))
  end

  sig do
    params(
      query: T.nilable(String),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::WorkflowExecutionCount)
  end
  def count_workflows(query = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      id: String,
      schedule: Temporalio::Client::Schedule,
      trigger_immediately: T::Boolean,
      backfills: T::Array[Temporalio::Client::Schedule::Backfill],
      memo: T.nilable(T::Hash[String, T.nilable(Object)]),
      search_attributes: T.nilable(Temporalio::SearchAttributes),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::ScheduleHandle)
  end
  def create_schedule(
    id,
    schedule,
    trigger_immediately: T.unsafe(nil),
    backfills: T.unsafe(nil),
    memo: T.unsafe(nil),
    search_attributes: T.unsafe(nil),
    rpc_options: T.unsafe(nil)
  )
  end
  sig { params(id: String).returns(Temporalio::Client::ScheduleHandle) }
  def schedule_handle(id); end

  sig do
    params(
      query: T.nilable(String),
      rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(T::Enumerator[Temporalio::Client::Schedule::List::Description])
  end
  def list_schedules(query = T.unsafe(nil), rpc_options: T.unsafe(nil)); end

  sig do
    params(
      task_token_or_id_reference: T.any(String, Temporalio::Client::ActivityIDReference)
    ).returns(Temporalio::Client::AsyncActivityHandle)
  end
  def async_activity_handle(task_token_or_id_reference); end

  class << self
    sig do
      params(
        target_host: String,
        namespace: String,
        api_key: T.nilable(String),
        tls: T.nilable(T.any(T::Boolean, Temporalio::Client::Connection::TLSOptions)),
        data_converter: Temporalio::Converters::DataConverter,
        plugins: T::Array[Temporalio::Client::Plugin],
        interceptors: T::Array[Temporalio::Client::Interceptor],
        logger: ::Logger,
        default_workflow_query_reject_condition: T.nilable(Integer),
        rpc_metadata: T::Hash[String, String],
        rpc_retry: Temporalio::Client::Connection::RPCRetryOptions,
        identity: String,
        keep_alive: Temporalio::Client::Connection::KeepAliveOptions,
        http_connect_proxy: T.nilable(Temporalio::Client::Connection::HTTPConnectProxyOptions),
        runtime: Temporalio::Runtime,
        lazy_connect: T::Boolean,
        dns_load_balancing: T.nilable(Temporalio::Client::Connection::DnsLoadBalancingOptions)
      ).returns(Temporalio::Client)
    end
    def connect(
      target_host,
      namespace,
      api_key: T.unsafe(nil),
      tls: T.unsafe(nil),
      data_converter: T.unsafe(nil),
      plugins: T.unsafe(nil),
      interceptors: T.unsafe(nil),
      logger: T.unsafe(nil),
      default_workflow_query_reject_condition: T.unsafe(nil),
      rpc_metadata: T.unsafe(nil),
      rpc_retry: T.unsafe(nil),
      identity: T.unsafe(nil),
      keep_alive: T.unsafe(nil),
      http_connect_proxy: T.unsafe(nil),
      runtime: T.unsafe(nil),
      lazy_connect: T.unsafe(nil),
      dns_load_balancing: T.unsafe(nil)
    )
    end
  end
end

class Temporalio::Client::Options < Data
  sig { returns(Temporalio::Client::Connection) }
  def connection; end

  sig { returns(String) }
  def namespace; end

  sig { returns(Temporalio::Converters::DataConverter) }
  def data_converter; end

  sig { returns(T::Array[Temporalio::Client::Plugin]) }
  def plugins; end

  sig { returns(T::Array[Temporalio::Client::Interceptor]) }
  def interceptors; end

  sig { returns(::Logger) }
  def logger; end

  sig { returns(T.nilable(Integer)) }
  def default_workflow_query_reject_condition; end

  sig { returns(T::Hash[Symbol, T.untyped]) }
  def to_h; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Client::Options) }
  def with(**kwargs); end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Options) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Options) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::ListWorkflowPage < Data
  sig { returns(T::Array[Temporalio::Client::WorkflowExecution]) }
  def executions; end

  sig { returns(T.nilable(String)) }
  def next_page_token; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::ListWorkflowPage) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::ListWorkflowPage) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::RPCOptions
  sig do
    params(
      metadata: T.nilable(T::Hash[String, String]),
      timeout: T.nilable(Float),
      cancellation: T.nilable(Temporalio::Cancellation),
      override_retry: T.nilable(T::Boolean)
    ).void
  end
  def initialize(metadata: T.unsafe(nil), timeout: T.unsafe(nil), cancellation: T.unsafe(nil),
                 override_retry: T.unsafe(nil))
  end

  sig { returns(T.nilable(T::Hash[String, String])) }
  attr_accessor :metadata

  sig { returns(T.nilable(Float)) }
  attr_accessor :timeout

  sig { returns(T.nilable(Temporalio::Cancellation)) }
  attr_accessor :cancellation

  sig { returns(T.nilable(T::Boolean)) }
  attr_accessor :override_retry
end
