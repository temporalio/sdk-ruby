use std::collections::HashMap;
use std::convert::TryFrom;
use std::str::FromStr;
use std::sync::Arc;
use std::time::Duration;
use temporal_client::{
    ClientInitError, ClientOptionsBuilder, ClientOptionsBuilderError, WorkflowService, RetryClient,
    ConfiguredClient, TemporalServiceClientWithMetrics
};
use thiserror::Error;
use tokio::{select};
use tokio::runtime::{Runtime};
use tokio_util::sync::CancellationToken;
use tonic::metadata::{MetadataKey,MetadataValue};
use url::Url;

pub type Client = RetryClient<ConfiguredClient<TemporalServiceClientWithMetrics>>;

#[derive(Error, Debug)]
pub enum ConnectionError {
    #[error(transparent)]
    InvalidUrl(#[from] url::ParseError),

    #[error(transparent)]
    InvalidProtobuf(#[from] prost::DecodeError),

    #[error(transparent)]
    InvalidConnectionOptions(#[from] ClientOptionsBuilderError),

    #[error("`{0}` RPC call is not supported by the API")]
    InvalidRpc(String),

    #[error(transparent)]
    InvalidRpcMetadataKey(#[from] tonic::metadata::errors::InvalidMetadataKey),

    #[error(transparent)]
    InvalidRpcMetadataValue(#[from] tonic::metadata::errors::InvalidMetadataValue),

    #[error(transparent)]
    UnableToConnect(#[from] ClientInitError),

    #[error(transparent)]
    UnableToInitializeRuntime(#[from] std::io::Error),

    #[error(transparent)]
    RequestError(#[from] tonic::Status),

    #[error("RPC call was cancelled")]
    RequestCancelled,
}

pub type RpcResult = Result<Vec<u8>, ConnectionError>;

fn rpc_req<P: prost::Message + Default>(params: RpcParams) -> Result<tonic::Request<P>, ConnectionError> {
    let proto = P::decode(&*params.request)?;
    let mut req = tonic::Request::new(proto);

    for (k, v) in &params.metadata {
        req.metadata_mut().insert(
            MetadataKey::from_str(k.as_str())?,
            MetadataValue::try_from(v.as_str())?
        );
    }

    if let Some(timeout_millis) = params.timeout_millis {
        req.set_timeout(Duration::from_millis(timeout_millis));
    }

    Ok(req)
}

fn rpc_resp<P: prost::Message + Default>(res: Result<tonic::Response<P>, tonic::Status>) -> RpcResult {
    Ok(res?.get_ref().encode_to_vec())
}

macro_rules! rpc_call {
    ($client:expr, $rpc:ident, $params:expr) => {
        rpc_resp($client.$rpc(rpc_req($params)?).await)
    };
}

async fn make_rpc_call(mut client: Client, params: RpcParams) -> RpcResult {
    match params.rpc.as_str() {
        "register_namespace" => rpc_call!(client, register_namespace, params),
        "describe_namespace" => rpc_call!(client, describe_namespace, params),
        "list_namespaces" => rpc_call!(client, list_namespaces, params),
        "update_namespace" => rpc_call!(client, update_namespace, params),
        "deprecate_namespace" => rpc_call!(client, deprecate_namespace, params),
        "start_workflow_execution" => rpc_call!(client, start_workflow_execution, params),
        "get_workflow_execution_history" => rpc_call!(client, get_workflow_execution_history, params),
        // "get_workflow_execution_history_reverse" => rpc_call!(client, get_workflow_execution_history_reverse, params),
        "poll_workflow_task_queue" => rpc_call!(client, poll_workflow_task_queue, params),
        "respond_workflow_task_completed" => rpc_call!(client, respond_workflow_task_completed, params),
        "respond_workflow_task_failed" => rpc_call!(client, respond_workflow_task_failed, params),
        "poll_activity_task_queue" => rpc_call!(client, poll_activity_task_queue, params),
        "record_activity_task_heartbeat" => rpc_call!(client, record_activity_task_heartbeat, params),
        "record_activity_task_heartbeat_by_id" => rpc_call!(client, record_activity_task_heartbeat_by_id, params),
        "respond_activity_task_completed" => rpc_call!(client, respond_activity_task_completed, params),
        "respond_activity_task_completed_by_id" => rpc_call!(client, respond_activity_task_completed_by_id, params),
        "respond_activity_task_failed" => rpc_call!(client, respond_activity_task_failed, params),
        "respond_activity_task_failed_by_id" => rpc_call!(client, respond_activity_task_failed_by_id, params),
        "respond_activity_task_canceled" => rpc_call!(client, respond_activity_task_canceled, params),
        "respond_activity_task_canceled_by_id" => rpc_call!(client, respond_activity_task_canceled_by_id, params),
        "request_cancel_workflow_execution" => rpc_call!(client, request_cancel_workflow_execution, params),
        "signal_workflow_execution" => rpc_call!(client, signal_workflow_execution, params),
        "signal_with_start_workflow_execution" => rpc_call!(client, signal_with_start_workflow_execution, params),
        "reset_workflow_execution" => rpc_call!(client, reset_workflow_execution, params),
        "terminate_workflow_execution" => rpc_call!(client, terminate_workflow_execution, params),
        "list_open_workflow_executions" => rpc_call!(client, list_open_workflow_executions, params),
        "list_closed_workflow_executions" => rpc_call!(client, list_closed_workflow_executions, params),
        "list_workflow_executions" => rpc_call!(client, list_workflow_executions, params),
        "list_archived_workflow_executions" => rpc_call!(client, list_archived_workflow_executions, params),
        "scan_workflow_executions" => rpc_call!(client, scan_workflow_executions, params),
        "count_workflow_executions" => rpc_call!(client, count_workflow_executions, params),
        "get_search_attributes" => rpc_call!(client, get_search_attributes, params),
        "respond_query_task_completed" => rpc_call!(client, respond_query_task_completed, params),
        "reset_sticky_task_queue" => rpc_call!(client, reset_sticky_task_queue, params),
        "query_workflow" => rpc_call!(client, query_workflow, params),
        "describe_workflow_execution" => rpc_call!(client, describe_workflow_execution, params),
        "describe_task_queue" => rpc_call!(client, describe_task_queue, params),
        "get_cluster_info" => rpc_call!(client, get_cluster_info, params),
        "get_system_info" => rpc_call!(client, get_system_info, params),
        "list_task_queue_partitions" => rpc_call!(client, list_task_queue_partitions, params),
        "create_schedule" => rpc_call!(client, create_schedule, params),
        "describe_schedule" => rpc_call!(client, describe_schedule, params),
        "update_schedule" => rpc_call!(client, update_schedule, params),
        "patch_schedule" => rpc_call!(client, patch_schedule, params),
        "list_schedule_matching_times" => rpc_call!(client, list_schedule_matching_times, params),
        "delete_schedule" => rpc_call!(client, delete_schedule, params),
        "list_schedules" => rpc_call!(client, list_schedules, params),
        "update_worker_build_id_ordering" => rpc_call!(client, update_worker_build_id_ordering, params),
        "get_worker_build_id_ordering" => rpc_call!(client, get_worker_build_id_ordering, params),
        "update_workflow" => rpc_call!(client, update_workflow, params),
        "start_batch_operation" => rpc_call!(client, start_batch_operation, params),
        "stop_batch_operation" => rpc_call!(client, stop_batch_operation, params),
        "describe_batch_operation" => rpc_call!(client, describe_batch_operation, params),
        "list_batch_operations" => rpc_call!(client, list_batch_operations, params),
        _ => Err(ConnectionError::InvalidRpc(params.rpc.to_string()))
    }
}

// A Connection is a Client wrapper for making RPC calls
pub struct Connection {
    pub client: Client,
    runtime: Arc<Runtime>
}

pub struct RpcParams {
    pub rpc: String,
    pub request: Vec<u8>,
    pub metadata: HashMap<String, String>,
    pub timeout_millis: Option<u64>
}

async fn create_client(host: String) -> Result<Client, ConnectionError> {
    let url = Url::try_from(&*host)?;
    let options = ClientOptionsBuilder::default()
        .identity("testtest".to_string())
        .target_url(url)
        .client_name("ruby-sdk".to_string())
        .client_version("0.0.1".to_string())
        .build()?;

    Ok(options.connect_no_namespace(None, None).await?)
}

impl Connection {
    // TODO: Change the interface to accept a full configuration
    pub fn connect(runtime: Arc<Runtime>, host: String) -> Result<Self, ConnectionError> {
        let client = runtime.block_on(create_client(host))?;

        Ok(Connection { client, runtime })
    }

    pub fn call(&self, params: RpcParams, cancel_token: CancellationToken) -> RpcResult {
        let core_client = self.client.clone();

        self.runtime.block_on(async move {
            select! {
                _ = cancel_token.cancelled() => Err(ConnectionError::RequestCancelled),
                result = make_rpc_call(core_client, params) => result
            }
        })
    }
}
