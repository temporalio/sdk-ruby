# typed: true

# Generated code.  DO NOT EDIT!

class Temporalio::Api::PayloadVisitor
  extend T::Sig

  sig do
    params(
      on_enter: T.nilable(T.proc.params(value: Object).returns(Object)),
      on_exit: T.nilable(T.proc.params(value: Object).returns(Object)),
      skip_search_attributes: T::Boolean,
      traverse_any: T::Boolean,
      block: T.proc.params(value: Object).returns(Object)
    ).void
  end
  def initialize(
    on_enter: T.unsafe(nil),
    on_exit: T.unsafe(nil),
    skip_search_attributes: T.unsafe(false),
    traverse_any: T.unsafe(false),
    &block
  ); end

  sig { params(value: Object).returns(NilClass) }
  def run(value); end

  sig { params(value: Object).void }
  def _run_activation(value); end

  sig { params(value: Object).void }
  def _run_activation_completion(value); end

  private

  sig { params(name: String).returns(String) }
  def method_name_from_proto_name(name); end

  sig { params(value: Object).returns(Object) }
  def api_common_v1_payload(value); end

  sig { params(value: Object).returns(Object) }
  def api_common_v1_payload_repeated(value); end

  sig { params(value: Object).void }
  def google_protobuf_any(value); end

sig { params(value: Object).void }
  def api_activity_v1_activity_execution_info(value); end
  
  sig { params(value: Object).void }
  def api_activity_v1_activity_execution_list_info(value); end
  
  sig { params(value: Object).void }
  def api_activity_v1_activity_execution_outcome(value); end
  
  sig { params(value: Object).void }
  def api_activity_v1_callback_info(value); end
  
  sig { params(value: Object).void }
  def api_batch_v1_batch_operation_reset(value); end
  
  sig { params(value: Object).void }
  def api_batch_v1_batch_operation_signal(value); end
  
  sig { params(value: Object).void }
  def api_batch_v1_batch_operation_termination(value); end
  
  sig { params(value: Object).void }
  def api_callback_v1_callback_info(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_add_namespace_region_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_add_user_group_member_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_account_audit_log_sink_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_api_key_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_billing_report_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_connectivity_rule_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_custom_role_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_namespace_export_sink_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_namespace_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_nexus_endpoint_request(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_nexus_endpoint_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_service_account_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_user_group_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_create_user_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_account_audit_log_sink_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_api_key_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_connectivity_rule_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_custom_role_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_namespace_export_sink_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_namespace_region_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_namespace_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_nexus_endpoint_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_service_account_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_user_group_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_delete_user_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_failover_namespace_region_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_get_async_operation_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_get_nexus_endpoint_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_get_nexus_endpoints_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_remove_user_group_member_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_rename_custom_search_attribute_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_set_service_account_namespace_access_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_set_user_group_namespace_access_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_set_user_namespace_access_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_account_audit_log_sink_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_account_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_api_key_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_custom_role_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_namespace_export_sink_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_namespace_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_namespace_tags_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_nexus_endpoint_request(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_nexus_endpoint_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_service_account_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_user_group_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_cloudservice_v1_update_user_response(value); end
  
  sig { params(value: Object).void }
  def api_cloud_nexus_v1_endpoint(value); end
  
  sig { params(value: Object).void }
  def api_cloud_nexus_v1_endpoint_spec(value); end
  
  sig { params(value: Object).void }
  def api_cloud_operation_v1_async_operation(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_cancel_workflow_execution_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_command(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_complete_workflow_execution_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_continue_as_new_workflow_execution_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_fail_workflow_execution_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_modify_workflow_properties_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_record_marker_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_schedule_activity_task_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_schedule_nexus_operation_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_signal_external_workflow_execution_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_start_child_workflow_execution_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_command_v1_upsert_workflow_search_attributes_command_attributes(value); end
  
  sig { params(value: Object).void }
  def api_common_v1_header(value); end
  
  sig { params(value: Object).void }
  def api_common_v1_memo(value); end
  
  sig { params(value: Object).void }
  def api_common_v1_payloads(value); end
  
  sig { params(value: Object).void }
  def api_common_v1_search_attributes(value); end
  
  sig { params(value: Object).void }
  def api_compute_v1_compute_config(value); end
  
  sig { params(value: Object).void }
  def api_compute_v1_compute_config_scaling_group(value); end
  
  sig { params(value: Object).void }
  def api_compute_v1_compute_config_scaling_group_update(value); end
  
  sig { params(value: Object).void }
  def api_compute_v1_compute_provider(value); end
  
  sig { params(value: Object).void }
  def api_compute_v1_compute_scaler(value); end
  
  sig { params(value: Object).void }
  def api_deployment_v1_deployment_info(value); end
  
  sig { params(value: Object).void }
  def api_deployment_v1_update_deployment_metadata(value); end
  
  sig { params(value: Object).void }
  def api_deployment_v1_version_metadata(value); end
  
  sig { params(value: Object).void }
  def api_deployment_v1_worker_deployment_version_info(value); end
  
  sig { params(value: Object).void }
  def api_export_v1_workflow_execution(value); end
  
  sig { params(value: Object).void }
  def api_export_v1_workflow_executions(value); end
  
  sig { params(value: Object).void }
  def api_failure_v1_application_failure_info(value); end
  
  sig { params(value: Object).void }
  def api_failure_v1_canceled_failure_info(value); end
  
  sig { params(value: Object).void }
  def api_failure_v1_failure(value); end
  
  sig { params(value: Object).void }
  def api_failure_v1_reset_workflow_failure_info(value); end
  
  sig { params(value: Object).void }
  def api_failure_v1_timeout_failure_info(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_activity_task_canceled_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_activity_task_completed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_activity_task_failed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_activity_task_scheduled_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_activity_task_started_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_activity_task_timed_out_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_child_workflow_execution_canceled_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_child_workflow_execution_completed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_child_workflow_execution_failed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_child_workflow_execution_started_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_history(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_history_event(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_marker_recorded_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_nexus_operation_cancel_request_failed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_nexus_operation_canceled_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_nexus_operation_completed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_nexus_operation_failed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_nexus_operation_scheduled_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_nexus_operation_timed_out_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_signal_external_workflow_execution_initiated_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_start_child_workflow_execution_initiated_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_upsert_workflow_search_attributes_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_canceled_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_completed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_continued_as_new_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_failed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_signaled_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_started_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_terminated_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_update_accepted_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_update_admitted_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_update_completed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_execution_update_rejected_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_properties_modified_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_properties_modified_externally_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_history_v1_workflow_task_failed_event_attributes(value); end
  
  sig { params(value: Object).void }
  def api_nexus_v1_endpoint(value); end
  
  sig { params(value: Object).void }
  def api_nexus_v1_endpoint_spec(value); end
  
  sig { params(value: Object).void }
  def api_nexus_v1_nexus_operation_execution_cancellation_info(value); end
  
  sig { params(value: Object).void }
  def api_nexus_v1_nexus_operation_execution_info(value); end
  
  sig { params(value: Object).void }
  def api_nexus_v1_nexus_operation_execution_list_info(value); end
  
  sig { params(value: Object).void }
  def api_nexus_v1_request(value); end
  
  sig { params(value: Object).void }
  def api_nexus_v1_response(value); end
  
  sig { params(value: Object).void }
  def api_nexus_v1_start_operation_request(value); end
  
  sig { params(value: Object).void }
  def api_nexus_v1_start_operation_response(value); end
  
  sig { params(value: Object).void }
  def api_nexus_v1_start_operation_response_sync(value); end
  
  sig { params(value: Object).void }
  def api_operatorservice_v1_create_nexus_endpoint_request(value); end
  
  sig { params(value: Object).void }
  def api_operatorservice_v1_create_nexus_endpoint_response(value); end
  
  sig { params(value: Object).void }
  def api_operatorservice_v1_get_nexus_endpoint_response(value); end
  
  sig { params(value: Object).void }
  def api_operatorservice_v1_list_nexus_endpoints_response(value); end
  
  sig { params(value: Object).void }
  def api_operatorservice_v1_update_nexus_endpoint_request(value); end
  
  sig { params(value: Object).void }
  def api_operatorservice_v1_update_nexus_endpoint_response(value); end
  
  sig { params(value: Object).void }
  def api_protocol_v1_message(value); end
  
  sig { params(value: Object).void }
  def api_query_v1_workflow_query(value); end
  
  sig { params(value: Object).void }
  def api_query_v1_workflow_query_result(value); end
  
  sig { params(value: Object).void }
  def api_schedule_v1_schedule(value); end
  
  sig { params(value: Object).void }
  def api_schedule_v1_schedule_action(value); end
  
  sig { params(value: Object).void }
  def api_schedule_v1_schedule_list_entry(value); end
  
  sig { params(value: Object).void }
  def api_sdk_v1_event_group_marker(value); end
  
  sig { params(value: Object).void }
  def api_sdk_v1_event_group_marker_label(value); end
  
  sig { params(value: Object).void }
  def api_sdk_v1_user_metadata(value); end
  
  sig { params(value: Object).void }
  def api_update_v1_input(value); end
  
  sig { params(value: Object).void }
  def api_update_v1_outcome(value); end
  
  sig { params(value: Object).void }
  def api_update_v1_request(value); end
  
  sig { params(value: Object).void }
  def api_workflow_v1_callback_info(value); end
  
  sig { params(value: Object).void }
  def api_workflow_v1_new_workflow_execution_info(value); end
  
  sig { params(value: Object).void }
  def api_workflow_v1_nexus_operation_cancellation_info(value); end
  
  sig { params(value: Object).void }
  def api_workflow_v1_pending_activity_info(value); end
  
  sig { params(value: Object).void }
  def api_workflow_v1_pending_nexus_operation_info(value); end
  
  sig { params(value: Object).void }
  def api_workflow_v1_post_reset_operation(value); end
  
  sig { params(value: Object).void }
  def api_workflow_v1_post_reset_operation_signal_workflow(value); end
  
  sig { params(value: Object).void }
  def api_workflow_v1_workflow_execution_config(value); end
  
  sig { params(value: Object).void }
  def api_workflow_v1_workflow_execution_info(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_count_activity_executions_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_count_activity_executions_response_aggregation_group(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_count_nexus_operation_executions_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_count_nexus_operation_executions_response_aggregation_group(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_count_schedules_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_count_schedules_response_aggregation_group(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_count_workflow_executions_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_count_workflow_executions_response_aggregation_group(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_create_schedule_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_create_worker_deployment_version_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_describe_activity_execution_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_describe_deployment_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_describe_nexus_operation_execution_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_describe_schedule_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_describe_worker_deployment_version_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_describe_workflow_execution_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_execute_multi_operation_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_execute_multi_operation_request_operation(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_execute_multi_operation_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_execute_multi_operation_response_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_get_current_deployment_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_get_deployment_reachability_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_get_workflow_execution_history_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_get_workflow_execution_history_reverse_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_list_activity_executions_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_list_archived_workflow_executions_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_list_closed_workflow_executions_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_list_nexus_operation_executions_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_list_open_workflow_executions_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_list_schedules_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_list_workflow_executions_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_poll_activity_execution_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_poll_activity_task_queue_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_poll_nexus_operation_execution_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_poll_nexus_task_queue_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_poll_workflow_execution_update_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_poll_workflow_task_queue_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_query_workflow_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_query_workflow_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_record_activity_task_heartbeat_by_id_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_record_activity_task_heartbeat_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_reset_workflow_execution_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_activity_task_canceled_by_id_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_activity_task_canceled_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_activity_task_completed_by_id_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_activity_task_completed_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_activity_task_failed_by_id_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_activity_task_failed_by_id_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_activity_task_failed_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_activity_task_failed_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_nexus_task_completed_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_nexus_task_failed_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_query_task_completed_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_workflow_task_completed_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_workflow_task_completed_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_respond_workflow_task_failed_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_scan_workflow_executions_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_set_current_deployment_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_set_current_deployment_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_signal_with_start_workflow_execution_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_signal_workflow_execution_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_start_activity_execution_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_start_batch_operation_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_start_nexus_operation_execution_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_start_workflow_execution_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_start_workflow_execution_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_terminate_workflow_execution_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_update_schedule_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_update_worker_deployment_version_compute_config_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_update_worker_deployment_version_metadata_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_update_worker_deployment_version_metadata_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_update_workflow_execution_request(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_update_workflow_execution_response(value); end
  
  sig { params(value: Object).void }
  def api_workflowservice_v1_validate_worker_deployment_version_compute_config_request(value); end
  
  sig { params(value: Object).void }
  def coresdk_activity_result_activity_resolution(value); end
  
  sig { params(value: Object).void }
  def coresdk_activity_result_cancellation(value); end
  
  sig { params(value: Object).void }
  def coresdk_activity_result_failure(value); end
  
  sig { params(value: Object).void }
  def coresdk_activity_result_success(value); end
  
  sig { params(value: Object).void }
  def coresdk_child_workflow_cancellation(value); end
  
  sig { params(value: Object).void }
  def coresdk_child_workflow_child_workflow_result(value); end
  
  sig { params(value: Object).void }
  def coresdk_child_workflow_failure(value); end
  
  sig { params(value: Object).void }
  def coresdk_child_workflow_success(value); end
  
  sig { params(value: Object).void }
  def coresdk_nexus_nexus_operation_result(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_do_update(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_initialize_workflow(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_query_workflow(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_resolve_activity(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_resolve_child_workflow_execution(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_resolve_child_workflow_execution_start(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_resolve_child_workflow_execution_start_cancelled(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_resolve_nexus_operation(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_resolve_nexus_operation_start(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_resolve_request_cancel_external_workflow(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_resolve_signal_external_workflow(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_signal_workflow(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_workflow_activation(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_activation_workflow_activation_job(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_complete_workflow_execution(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_continue_as_new_workflow_execution(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_fail_workflow_execution(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_modify_workflow_properties(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_query_result(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_query_success(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_schedule_activity(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_schedule_local_activity(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_schedule_nexus_operation(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_signal_external_workflow_execution(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_start_child_workflow_execution(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_update_response(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_upsert_workflow_search_attributes(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_commands_workflow_command(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_completion_failure(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_completion_success(value); end
  
  sig { params(value: Object).void }
  def coresdk_workflow_completion_workflow_activation_completion(value); end
  
end
