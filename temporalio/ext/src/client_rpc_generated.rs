// Generated code.  DO NOT EDIT!

use magnus::{Error, Ruby};
use temporal_client::{CloudService, OperatorService, TestService, WorkflowService};

use super::{error, rpc_call};
use crate::{
    client::{Client, RpcCall, SERVICE_CLOUD, SERVICE_OPERATOR, SERVICE_TEST, SERVICE_WORKFLOW},
    util::AsyncCallback,
};

impl Client {
    pub fn invoke_rpc(
        &self,
        service: u8,
        callback: AsyncCallback,
        call: RpcCall,
    ) -> Result<(), Error> {
        match service {
            SERVICE_WORKFLOW => match call.rpc.as_str() {
                "count_workflow_executions" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    count_workflow_executions
                ),
                "create_schedule" => {
                    rpc_call!(self, callback, call, WorkflowService, create_schedule)
                }
                "delete_schedule" => {
                    rpc_call!(self, callback, call, WorkflowService, delete_schedule)
                }
                "delete_workflow_execution" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    delete_workflow_execution
                ),
                "deprecate_namespace" => {
                    rpc_call!(self, callback, call, WorkflowService, deprecate_namespace)
                }
                "describe_batch_operation" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    describe_batch_operation
                ),
                "describe_namespace" => {
                    rpc_call!(self, callback, call, WorkflowService, describe_namespace)
                }
                "describe_schedule" => {
                    rpc_call!(self, callback, call, WorkflowService, describe_schedule)
                }
                "describe_task_queue" => {
                    rpc_call!(self, callback, call, WorkflowService, describe_task_queue)
                }
                "describe_workflow_execution" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    describe_workflow_execution
                ),
                "execute_multi_operation" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    execute_multi_operation
                ),
                "get_cluster_info" => {
                    rpc_call!(self, callback, call, WorkflowService, get_cluster_info)
                }
                "get_search_attributes" => {
                    rpc_call!(self, callback, call, WorkflowService, get_search_attributes)
                }
                "get_system_info" => {
                    rpc_call!(self, callback, call, WorkflowService, get_system_info)
                }
                "get_worker_build_id_compatibility" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    get_worker_build_id_compatibility
                ),
                "get_worker_task_reachability" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    get_worker_task_reachability
                ),
                "get_worker_versioning_rules" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    get_worker_versioning_rules
                ),
                "get_workflow_execution_history" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    get_workflow_execution_history
                ),
                "get_workflow_execution_history_reverse" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    get_workflow_execution_history_reverse
                ),
                "list_archived_workflow_executions" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    list_archived_workflow_executions
                ),
                "list_batch_operations" => {
                    rpc_call!(self, callback, call, WorkflowService, list_batch_operations)
                }
                "list_closed_workflow_executions" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    list_closed_workflow_executions
                ),
                "list_namespaces" => {
                    rpc_call!(self, callback, call, WorkflowService, list_namespaces)
                }
                "list_open_workflow_executions" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    list_open_workflow_executions
                ),
                "list_schedule_matching_times" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    list_schedule_matching_times
                ),
                "list_schedules" => {
                    rpc_call!(self, callback, call, WorkflowService, list_schedules)
                }
                "list_task_queue_partitions" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    list_task_queue_partitions
                ),
                "list_workflow_executions" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    list_workflow_executions
                ),
                "patch_schedule" => {
                    rpc_call!(self, callback, call, WorkflowService, patch_schedule)
                }
                "pause_activity_by_id" => {
                    rpc_call!(self, callback, call, WorkflowService, pause_activity_by_id)
                }
                "poll_activity_task_queue" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    poll_activity_task_queue
                ),
                "poll_nexus_task_queue" => {
                    rpc_call!(self, callback, call, WorkflowService, poll_nexus_task_queue)
                }
                "poll_workflow_execution_update" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    poll_workflow_execution_update
                ),
                "poll_workflow_task_queue" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    poll_workflow_task_queue
                ),
                "query_workflow" => {
                    rpc_call!(self, callback, call, WorkflowService, query_workflow)
                }
                "record_activity_task_heartbeat" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    record_activity_task_heartbeat
                ),
                "record_activity_task_heartbeat_by_id" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    record_activity_task_heartbeat_by_id
                ),
                "register_namespace" => {
                    rpc_call!(self, callback, call, WorkflowService, register_namespace)
                }
                "request_cancel_workflow_execution" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    request_cancel_workflow_execution
                ),
                "reset_activity_by_id" => {
                    rpc_call!(self, callback, call, WorkflowService, reset_activity_by_id)
                }
                "reset_sticky_task_queue" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    reset_sticky_task_queue
                ),
                "reset_workflow_execution" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    reset_workflow_execution
                ),
                "respond_activity_task_canceled" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_activity_task_canceled
                ),
                "respond_activity_task_canceled_by_id" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_activity_task_canceled_by_id
                ),
                "respond_activity_task_completed" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_activity_task_completed
                ),
                "respond_activity_task_completed_by_id" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_activity_task_completed_by_id
                ),
                "respond_activity_task_failed" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_activity_task_failed
                ),
                "respond_activity_task_failed_by_id" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_activity_task_failed_by_id
                ),
                "respond_nexus_task_completed" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_nexus_task_completed
                ),
                "respond_nexus_task_failed" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_nexus_task_failed
                ),
                "respond_query_task_completed" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_query_task_completed
                ),
                "respond_workflow_task_completed" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_workflow_task_completed
                ),
                "respond_workflow_task_failed" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    respond_workflow_task_failed
                ),
                "scan_workflow_executions" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    scan_workflow_executions
                ),
                "shutdown_worker" => {
                    rpc_call!(self, callback, call, WorkflowService, shutdown_worker)
                }
                "signal_with_start_workflow_execution" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    signal_with_start_workflow_execution
                ),
                "signal_workflow_execution" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    signal_workflow_execution
                ),
                "start_batch_operation" => {
                    rpc_call!(self, callback, call, WorkflowService, start_batch_operation)
                }
                "start_workflow_execution" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    start_workflow_execution
                ),
                "stop_batch_operation" => {
                    rpc_call!(self, callback, call, WorkflowService, stop_batch_operation)
                }
                "terminate_workflow_execution" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    terminate_workflow_execution
                ),
                "unpause_activity_by_id" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    unpause_activity_by_id
                ),
                "update_activity_options_by_id" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    update_activity_options_by_id
                ),
                "update_namespace" => {
                    rpc_call!(self, callback, call, WorkflowService, update_namespace)
                }
                "update_schedule" => {
                    rpc_call!(self, callback, call, WorkflowService, update_schedule)
                }
                "update_worker_build_id_compatibility" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    update_worker_build_id_compatibility
                ),
                "update_worker_versioning_rules" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    update_worker_versioning_rules
                ),
                "update_workflow_execution" => rpc_call!(
                    self,
                    callback,
                    call,
                    WorkflowService,
                    update_workflow_execution
                ),
                _ => Err(error!("Unknown RPC call {}", call.rpc)),
            },
            SERVICE_OPERATOR => match call.rpc.as_str() {
                "add_or_update_remote_cluster" => rpc_call!(
                    self,
                    callback,
                    call,
                    OperatorService,
                    add_or_update_remote_cluster
                ),
                "add_search_attributes" => {
                    rpc_call!(self, callback, call, OperatorService, add_search_attributes)
                }
                "create_nexus_endpoint" => {
                    rpc_call!(self, callback, call, OperatorService, create_nexus_endpoint)
                }
                "delete_namespace" => {
                    rpc_call!(self, callback, call, OperatorService, delete_namespace)
                }
                "delete_nexus_endpoint" => {
                    rpc_call!(self, callback, call, OperatorService, delete_nexus_endpoint)
                }
                "get_nexus_endpoint" => {
                    rpc_call!(self, callback, call, OperatorService, get_nexus_endpoint)
                }
                "list_clusters" => rpc_call!(self, callback, call, OperatorService, list_clusters),
                "list_nexus_endpoints" => {
                    rpc_call!(self, callback, call, OperatorService, list_nexus_endpoints)
                }
                "list_search_attributes" => rpc_call!(
                    self,
                    callback,
                    call,
                    OperatorService,
                    list_search_attributes
                ),
                "remove_remote_cluster" => {
                    rpc_call!(self, callback, call, OperatorService, remove_remote_cluster)
                }
                "remove_search_attributes" => rpc_call!(
                    self,
                    callback,
                    call,
                    OperatorService,
                    remove_search_attributes
                ),
                "update_nexus_endpoint" => {
                    rpc_call!(self, callback, call, OperatorService, update_nexus_endpoint)
                }
                _ => Err(error!("Unknown RPC call {}", call.rpc)),
            },
            SERVICE_CLOUD => match call.rpc.as_str() {
                "add_namespace_region" => {
                    rpc_call!(self, callback, call, CloudService, add_namespace_region)
                }
                "create_api_key" => rpc_call!(self, callback, call, CloudService, create_api_key),
                "create_namespace" => {
                    rpc_call!(self, callback, call, CloudService, create_namespace)
                }
                "create_namespace_export_sink" => rpc_call!(
                    self,
                    callback,
                    call,
                    CloudService,
                    create_namespace_export_sink
                ),
                "create_nexus_endpoint" => {
                    rpc_call!(self, callback, call, CloudService, create_nexus_endpoint)
                }
                "create_service_account" => {
                    rpc_call!(self, callback, call, CloudService, create_service_account)
                }
                "create_user" => rpc_call!(self, callback, call, CloudService, create_user),
                "create_user_group" => {
                    rpc_call!(self, callback, call, CloudService, create_user_group)
                }
                "delete_api_key" => rpc_call!(self, callback, call, CloudService, delete_api_key),
                "delete_namespace" => {
                    rpc_call!(self, callback, call, CloudService, delete_namespace)
                }
                "delete_namespace_export_sink" => rpc_call!(
                    self,
                    callback,
                    call,
                    CloudService,
                    delete_namespace_export_sink
                ),
                "delete_nexus_endpoint" => {
                    rpc_call!(self, callback, call, CloudService, delete_nexus_endpoint)
                }
                "delete_service_account" => {
                    rpc_call!(self, callback, call, CloudService, delete_service_account)
                }
                "delete_user" => rpc_call!(self, callback, call, CloudService, delete_user),
                "delete_user_group" => {
                    rpc_call!(self, callback, call, CloudService, delete_user_group)
                }
                "failover_namespace_region" => rpc_call!(
                    self,
                    callback,
                    call,
                    CloudService,
                    failover_namespace_region
                ),
                "get_account" => rpc_call!(self, callback, call, CloudService, get_account),
                "get_api_key" => rpc_call!(self, callback, call, CloudService, get_api_key),
                "get_api_keys" => rpc_call!(self, callback, call, CloudService, get_api_keys),
                "get_async_operation" => {
                    rpc_call!(self, callback, call, CloudService, get_async_operation)
                }
                "get_namespace" => rpc_call!(self, callback, call, CloudService, get_namespace),
                "get_namespace_export_sink" => rpc_call!(
                    self,
                    callback,
                    call,
                    CloudService,
                    get_namespace_export_sink
                ),
                "get_namespace_export_sinks" => rpc_call!(
                    self,
                    callback,
                    call,
                    CloudService,
                    get_namespace_export_sinks
                ),
                "get_namespaces" => rpc_call!(self, callback, call, CloudService, get_namespaces),
                "get_nexus_endpoint" => {
                    rpc_call!(self, callback, call, CloudService, get_nexus_endpoint)
                }
                "get_nexus_endpoints" => {
                    rpc_call!(self, callback, call, CloudService, get_nexus_endpoints)
                }
                "get_region" => rpc_call!(self, callback, call, CloudService, get_region),
                "get_regions" => rpc_call!(self, callback, call, CloudService, get_regions),
                "get_service_account" => {
                    rpc_call!(self, callback, call, CloudService, get_service_account)
                }
                "get_service_accounts" => {
                    rpc_call!(self, callback, call, CloudService, get_service_accounts)
                }
                "get_usage" => rpc_call!(self, callback, call, CloudService, get_usage),
                "get_user" => rpc_call!(self, callback, call, CloudService, get_user),
                "get_user_group" => rpc_call!(self, callback, call, CloudService, get_user_group),
                "get_user_groups" => rpc_call!(self, callback, call, CloudService, get_user_groups),
                "get_users" => rpc_call!(self, callback, call, CloudService, get_users),
                "rename_custom_search_attribute" => rpc_call!(
                    self,
                    callback,
                    call,
                    CloudService,
                    rename_custom_search_attribute
                ),
                "set_user_group_namespace_access" => rpc_call!(
                    self,
                    callback,
                    call,
                    CloudService,
                    set_user_group_namespace_access
                ),
                "set_user_namespace_access" => rpc_call!(
                    self,
                    callback,
                    call,
                    CloudService,
                    set_user_namespace_access
                ),
                "update_account" => rpc_call!(self, callback, call, CloudService, update_account),
                "update_api_key" => rpc_call!(self, callback, call, CloudService, update_api_key),
                "update_namespace" => {
                    rpc_call!(self, callback, call, CloudService, update_namespace)
                }
                "update_namespace_export_sink" => rpc_call!(
                    self,
                    callback,
                    call,
                    CloudService,
                    update_namespace_export_sink
                ),
                "update_nexus_endpoint" => {
                    rpc_call!(self, callback, call, CloudService, update_nexus_endpoint)
                }
                "update_service_account" => {
                    rpc_call!(self, callback, call, CloudService, update_service_account)
                }
                "update_user" => rpc_call!(self, callback, call, CloudService, update_user),
                "update_user_group" => {
                    rpc_call!(self, callback, call, CloudService, update_user_group)
                }
                "validate_namespace_export_sink" => rpc_call!(
                    self,
                    callback,
                    call,
                    CloudService,
                    validate_namespace_export_sink
                ),
                _ => Err(error!("Unknown RPC call {}", call.rpc)),
            },
            SERVICE_TEST => match call.rpc.as_str() {
                "get_current_time" => {
                    rpc_call!(self, callback, call, TestService, get_current_time)
                }
                "lock_time_skipping" => {
                    rpc_call!(self, callback, call, TestService, lock_time_skipping)
                }
                "sleep" => rpc_call!(self, callback, call, TestService, sleep),
                "sleep_until" => rpc_call!(self, callback, call, TestService, sleep_until),
                "unlock_time_skipping" => {
                    rpc_call!(self, callback, call, TestService, unlock_time_skipping)
                }
                "unlock_time_skipping_with_sleep" => rpc_call!(
                    self,
                    callback,
                    call,
                    TestService,
                    unlock_time_skipping_with_sleep
                ),
                _ => Err(error!("Unknown RPC call {}", call.rpc)),
            },
            _ => Err(error!("Unknown service")),
        }
    }
}
