use std::convert::TryFrom;
use temporal_client::{
    ClientInitError, ClientOptionsBuilder, ClientOptionsBuilderError, WorkflowService, RetryClient,
    ConfiguredClient, WorkflowServiceClientWithMetrics
};
use thiserror::Error;
use tokio::runtime::{Builder, Runtime};
use tonic::Request;
use url::Url;

pub type Client = RetryClient<ConfiguredClient<WorkflowServiceClientWithMetrics>>;

#[derive(Error, Debug)]
pub enum ConnectionError {
    #[error(transparent)]
    InvalidUrl(#[from] url::ParseError),

    #[error(transparent)]
    InvalidProtobuf(#[from] prost::DecodeError),

    #[error(transparent)]
    InvalidConnectionOptions(#[from] ClientOptionsBuilderError),

    #[error("provided RPC call is not supported by the API")]
    InvalidRpc,

    #[error(transparent)]
    UnableToConnect(#[from] ClientInitError),

    #[error(transparent)]
    UnableToInitializeRuntime(#[from] std::io::Error),

    #[error(transparent)]
    RequestError(#[from] tonic::Status),
}

fn rpc_req<P: prost::Message + Default>(bytes: Vec<u8>) -> Result<tonic::Request<P>, prost::DecodeError> {
    let proto = P::decode(&*bytes)?;
    Ok(Request::new(proto))
}

fn rpc_resp<P: prost::Message + Default>(res: Result<tonic::Response<P>, tonic::Status>) -> Result<Vec<u8>, ConnectionError> {
    Ok(res?.get_ref().encode_to_vec())
}

macro_rules! rpc_call {
    ($client:expr, $runtime:expr, $rpc:ident, $bytes:expr) => {
        rpc_resp($runtime.block_on($client.$rpc(rpc_req($bytes)?)))
    };
}

// A Connection is a Client wrapper for making RPC calls
#[derive(Debug)]
pub struct Connection {
    client: Client,
    runtime: Runtime
}

async fn create_client(host: String) -> Result<Client, ConnectionError> {
    let url = Url::try_from(&*host)?;
    let options = ClientOptionsBuilder::default()
        .identity("testtest".to_string())
        .worker_binary_id("fakebinaryid".to_string())
        .target_url(url)
        .client_name("ruby-sdk".to_string())
        .client_version("0.0.1".to_string())
        .build()?;

    Ok(options.connect_no_namespace(None, None).await?)
}

impl Connection {
    // TODO: Change the interface to accept a full configuration
    pub fn connect(host: String) -> Result<Self, ConnectionError> {
        let runtime = Builder::new_current_thread().enable_all().build()?;
        let client = runtime.block_on(create_client(host))?;

        Ok(Connection { client: client, runtime })
    }

    pub fn call(&mut self, rpc: &str, bytes: Vec<u8>) -> Result<Vec<u8>, ConnectionError> {
        match rpc {
            "register_namespace" => rpc_call!(self.client, self.runtime, register_namespace, bytes),
            "describe_namespace" => rpc_call!(self.client, self.runtime, describe_namespace, bytes),
            "list_namespaces" => rpc_call!(self.client, self.runtime, list_namespaces, bytes),
            "update_namespace" => rpc_call!(self.client, self.runtime, update_namespace, bytes),
            "deprecate_namespace" => rpc_call!(self.client, self.runtime, deprecate_namespace, bytes),
            "start_workflow_execution" => rpc_call!(self.client, self.runtime, start_workflow_execution, bytes),
            "get_workflow_execution_history" => rpc_call!(self.client, self.runtime, get_workflow_execution_history, bytes),
            // "get_workflow_execution_history_reverse" => rpc_call!(self.client, self.runtime, get_workflow_execution_history_reverse, bytes),
            "poll_workflow_task_queue" => rpc_call!(self.client, self.runtime, poll_workflow_task_queue, bytes),
            "respond_workflow_task_completed" => rpc_call!(self.client, self.runtime, respond_workflow_task_completed, bytes),
            "respond_workflow_task_failed" => rpc_call!(self.client, self.runtime, respond_workflow_task_failed, bytes),
            "poll_activity_task_queue" => rpc_call!(self.client, self.runtime, poll_activity_task_queue, bytes),
            "record_activity_task_heartbeat" => rpc_call!(self.client, self.runtime, record_activity_task_heartbeat, bytes),
            "record_activity_task_heartbeat_by_id" => rpc_call!(self.client, self.runtime, record_activity_task_heartbeat_by_id, bytes),
            "respond_activity_task_completed" => rpc_call!(self.client, self.runtime, respond_activity_task_completed, bytes),
            "respond_activity_task_completed_by_id" => rpc_call!(self.client, self.runtime, respond_activity_task_completed_by_id, bytes),
            "respond_activity_task_failed" => rpc_call!(self.client, self.runtime, respond_activity_task_failed, bytes),
            "respond_activity_task_failed_by_id" => rpc_call!(self.client, self.runtime, respond_activity_task_failed_by_id, bytes),
            "respond_activity_task_canceled" => rpc_call!(self.client, self.runtime, respond_activity_task_canceled, bytes),
            "respond_activity_task_canceled_by_id" => rpc_call!(self.client, self.runtime, respond_activity_task_canceled_by_id, bytes),
            "request_cancel_workflow_execution" => rpc_call!(self.client, self.runtime, request_cancel_workflow_execution, bytes),
            "signal_workflow_execution" => rpc_call!(self.client, self.runtime, signal_workflow_execution, bytes),
            "signal_with_start_workflow_execution" => rpc_call!(self.client, self.runtime, signal_with_start_workflow_execution, bytes),
            "reset_workflow_execution" => rpc_call!(self.client, self.runtime, reset_workflow_execution, bytes),
            "terminate_workflow_execution" => rpc_call!(self.client, self.runtime, terminate_workflow_execution, bytes),
            "list_open_workflow_executions" => rpc_call!(self.client, self.runtime, list_open_workflow_executions, bytes),
            "list_closed_workflow_executions" => rpc_call!(self.client, self.runtime, list_closed_workflow_executions, bytes),
            "list_workflow_executions" => rpc_call!(self.client, self.runtime, list_workflow_executions, bytes),
            "list_archived_workflow_executions" => rpc_call!(self.client, self.runtime, list_archived_workflow_executions, bytes),
            "scan_workflow_executions" => rpc_call!(self.client, self.runtime, scan_workflow_executions, bytes),
            "count_workflow_executions" => rpc_call!(self.client, self.runtime, count_workflow_executions, bytes),
            "get_search_attributes" => rpc_call!(self.client, self.runtime, get_search_attributes, bytes),
            "respond_query_task_completed" => rpc_call!(self.client, self.runtime, respond_query_task_completed, bytes),
            "reset_sticky_task_queue" => rpc_call!(self.client, self.runtime, reset_sticky_task_queue, bytes),
            "query_workflow" => rpc_call!(self.client, self.runtime, query_workflow, bytes),
            "describe_workflow_execution" => rpc_call!(self.client, self.runtime, describe_workflow_execution, bytes),
            "describe_task_queue" => rpc_call!(self.client, self.runtime, describe_task_queue, bytes),
            "get_cluster_info" => rpc_call!(self.client, self.runtime, get_cluster_info, bytes),
            "get_system_info" => rpc_call!(self.client, self.runtime, get_system_info, bytes),
            "list_task_queue_partitions" => rpc_call!(self.client, self.runtime, list_task_queue_partitions, bytes),
            _ => return Err(ConnectionError::InvalidRpc)
        }
    }
}
