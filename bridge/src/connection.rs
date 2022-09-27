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
use tokio::runtime::{Runtime};
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
}

fn rpc_req<P: prost::Message + Default>(params: RpcParams) -> Result<tonic::Request<P>, ConnectionError> {
    let proto = P::decode(&*params.request)?;
    let mut req = tonic::Request::new(proto);

    for (k, v) in params.metadata {
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

fn rpc_resp<P: prost::Message + Default>(res: Result<tonic::Response<P>, tonic::Status>) -> Result<Vec<u8>, ConnectionError> {
    Ok(res?.get_ref().encode_to_vec())
}

macro_rules! rpc_call {
    ($client:expr, $runtime:expr, $rpc:ident, $params:expr) => {
        rpc_resp($runtime.block_on($client.$rpc(rpc_req($params)?)))
    };
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

        Ok(Connection { client: client, runtime })
    }

    pub fn call(&mut self, params: RpcParams) -> Result<Vec<u8>, ConnectionError> {
        match params.rpc.as_str() {
            "register_namespace" => rpc_call!(self.client, self.runtime, register_namespace, params),
            "describe_namespace" => rpc_call!(self.client, self.runtime, describe_namespace, params),
            "list_namespaces" => rpc_call!(self.client, self.runtime, list_namespaces, params),
            "update_namespace" => rpc_call!(self.client, self.runtime, update_namespace, params),
            "deprecate_namespace" => rpc_call!(self.client, self.runtime, deprecate_namespace, params),
            "start_workflow_execution" => rpc_call!(self.client, self.runtime, start_workflow_execution, params),
            "get_workflow_execution_history" => rpc_call!(self.client, self.runtime, get_workflow_execution_history, params),
            // "get_workflow_execution_history_reverse" => rpc_call!(self.client, self.runtime, get_workflow_execution_history_reverse, params),
            "poll_workflow_task_queue" => rpc_call!(self.client, self.runtime, poll_workflow_task_queue, params),
            "respond_workflow_task_completed" => rpc_call!(self.client, self.runtime, respond_workflow_task_completed, params),
            "respond_workflow_task_failed" => rpc_call!(self.client, self.runtime, respond_workflow_task_failed, params),
            "poll_activity_task_queue" => rpc_call!(self.client, self.runtime, poll_activity_task_queue, params),
            "record_activity_task_heartbeat" => rpc_call!(self.client, self.runtime, record_activity_task_heartbeat, params),
            "record_activity_task_heartbeat_by_id" => rpc_call!(self.client, self.runtime, record_activity_task_heartbeat_by_id, params),
            "respond_activity_task_completed" => rpc_call!(self.client, self.runtime, respond_activity_task_completed, params),
            "respond_activity_task_completed_by_id" => rpc_call!(self.client, self.runtime, respond_activity_task_completed_by_id, params),
            "respond_activity_task_failed" => rpc_call!(self.client, self.runtime, respond_activity_task_failed, params),
            "respond_activity_task_failed_by_id" => rpc_call!(self.client, self.runtime, respond_activity_task_failed_by_id, params),
            "respond_activity_task_canceled" => rpc_call!(self.client, self.runtime, respond_activity_task_canceled, params),
            "respond_activity_task_canceled_by_id" => rpc_call!(self.client, self.runtime, respond_activity_task_canceled_by_id, params),
            "request_cancel_workflow_execution" => rpc_call!(self.client, self.runtime, request_cancel_workflow_execution, params),
            "signal_workflow_execution" => rpc_call!(self.client, self.runtime, signal_workflow_execution, params),
            "signal_with_start_workflow_execution" => rpc_call!(self.client, self.runtime, signal_with_start_workflow_execution, params),
            "reset_workflow_execution" => rpc_call!(self.client, self.runtime, reset_workflow_execution, params),
            "terminate_workflow_execution" => rpc_call!(self.client, self.runtime, terminate_workflow_execution, params),
            "list_open_workflow_executions" => rpc_call!(self.client, self.runtime, list_open_workflow_executions, params),
            "list_closed_workflow_executions" => rpc_call!(self.client, self.runtime, list_closed_workflow_executions, params),
            "list_workflow_executions" => rpc_call!(self.client, self.runtime, list_workflow_executions, params),
            "list_archived_workflow_executions" => rpc_call!(self.client, self.runtime, list_archived_workflow_executions, params),
            "scan_workflow_executions" => rpc_call!(self.client, self.runtime, scan_workflow_executions, params),
            "count_workflow_executions" => rpc_call!(self.client, self.runtime, count_workflow_executions, params),
            "get_search_attributes" => rpc_call!(self.client, self.runtime, get_search_attributes, params),
            "respond_query_task_completed" => rpc_call!(self.client, self.runtime, respond_query_task_completed, params),
            "reset_sticky_task_queue" => rpc_call!(self.client, self.runtime, reset_sticky_task_queue, params),
            "query_workflow" => rpc_call!(self.client, self.runtime, query_workflow, params),
            "describe_workflow_execution" => rpc_call!(self.client, self.runtime, describe_workflow_execution, params),
            "describe_task_queue" => rpc_call!(self.client, self.runtime, describe_task_queue, params),
            "get_cluster_info" => rpc_call!(self.client, self.runtime, get_cluster_info, params),
            "get_system_info" => rpc_call!(self.client, self.runtime, get_system_info, params),
            "list_task_queue_partitions" => rpc_call!(self.client, self.runtime, list_task_queue_partitions, params),
            _ => return Err(ConnectionError::InvalidRpc(params.rpc.to_string()))
        }
    }
}
