# frozen_string_literal: true

# Generated code.  DO NOT EDIT!

require 'temporalio/api'
require 'temporalio/internal/bridge/api'

module Temporalio
  module Api
    # Visitor for payloads within the protobuf structure. This visitor is thread safe and can be used multiple
    # times since it stores no mutable state.
    #
    # @note WARNING: This class is not considered stable for external use and may change as needed for internal
    #   reasons.
    class PayloadVisitor
      # Create a new visitor, calling the block on every {Common::V1::Payload} or
      # {Google::Protobuf::RepeatedField<Payload>} encountered.
      #
      # @param on_enter [Proc, nil] Proc called at the beginning of the processing for every protobuf value
      #   _except_ the ones calling the block.
      # @param on_exit [Proc, nil] Proc called at the end of the processing for every protobuf value _except_ the
      #   ones calling the block.
      # @param skip_search_attributes [Boolean] If true, payloads within search attributes do not call the block.
      # @param traverse_any [Boolean] If true, when a [Google::Protobuf::Any] is encountered, it is unpacked,
      #   visited, then repacked.
      # @yield [value] Block called with the visited payload value.
      # @yieldparam [Common::V1::Payload, Google::Protobuf::RepeatedField<Payload>] Payload or payload list.
      def initialize(
        on_enter: nil,
        on_exit: nil,
        skip_search_attributes: false,
        traverse_any: false,
        &block
      )
        raise ArgumentError, 'Block required' unless block_given?
        @on_enter = on_enter
        @on_exit = on_exit
        @skip_search_attributes = skip_search_attributes
        @traverse_any = traverse_any
        @block = block
      end

      # Visit the given protobuf message.
      #
      # @param value [Google::Protobuf::Message] Message to visit.
      def run(value)
        return unless value.is_a?(Google::Protobuf::MessageExts)
        method_name = method_name_from_proto_name(value.class.descriptor.name)
        send(method_name, value) if respond_to?(method_name, true)
        nil
      end

      # @!visibility private
      def _run_activation(value)
        coresdk_workflow_activation_workflow_activation(value)
      end

      # @!visibility private
      def _run_activation_completion(value)
        coresdk_workflow_completion_workflow_activation_completion(value)
      end

      private

      def method_name_from_proto_name(name)
        name
            .sub('temporal.api.', 'api_')
            .gsub('.', '_')
            .gsub(/([a-z])([A-Z])/, '\1_\2')
            .downcase
      end

      def api_common_v1_payload(value)
        @block.call(value)
      end

      def api_common_v1_payload_repeated(value)
        @block.call(value)
      end

      def google_protobuf_any(value)
        return unless @traverse_any
        desc = Google::Protobuf::DescriptorPool.generated_pool.lookup(value.type_name)
        unpacked = value.unpack(desc.msgclass)
        run(unpacked)
        value.pack(unpacked)
      end

      ### Generated method bodies below ###

      def api_batch_v1_batch_operation_reset(value)
        @on_enter&.call(value)
        value.post_reset_operations.each { |v| api_workflow_v1_post_reset_operation(v) }
        @on_exit&.call(value)
      end
      
      def api_batch_v1_batch_operation_signal(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_header(value.header) if value.has_header?
        @on_exit&.call(value)
      end
      
      def api_batch_v1_batch_operation_termination(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_add_namespace_region_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_add_user_group_member_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_create_api_key_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_create_connectivity_rule_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_create_namespace_export_sink_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_create_namespace_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_create_nexus_endpoint_request(value)
        @on_enter&.call(value)
        api_cloud_nexus_v1_endpoint_spec(value.spec) if value.has_spec?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_create_nexus_endpoint_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_create_service_account_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_create_user_group_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_create_user_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_delete_api_key_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_delete_connectivity_rule_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_delete_namespace_export_sink_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_delete_namespace_region_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_delete_namespace_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_delete_nexus_endpoint_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_delete_service_account_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_delete_user_group_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_delete_user_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_failover_namespace_region_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_get_async_operation_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_get_nexus_endpoint_response(value)
        @on_enter&.call(value)
        api_cloud_nexus_v1_endpoint(value.endpoint) if value.has_endpoint?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_get_nexus_endpoints_response(value)
        @on_enter&.call(value)
        value.endpoints.each { |v| api_cloud_nexus_v1_endpoint(v) }
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_remove_user_group_member_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_rename_custom_search_attribute_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_set_service_account_namespace_access_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_set_user_group_namespace_access_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_set_user_namespace_access_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_update_account_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_update_api_key_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_update_namespace_export_sink_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_update_namespace_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_update_namespace_tags_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_update_nexus_endpoint_request(value)
        @on_enter&.call(value)
        api_cloud_nexus_v1_endpoint_spec(value.spec) if value.has_spec?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_update_nexus_endpoint_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_update_service_account_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_update_user_group_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_cloudservice_v1_update_user_response(value)
        @on_enter&.call(value)
        api_cloud_operation_v1_async_operation(value.async_operation) if value.has_async_operation?
        @on_exit&.call(value)
      end
      
      def api_cloud_nexus_v1_endpoint(value)
        @on_enter&.call(value)
        api_cloud_nexus_v1_endpoint_spec(value.spec) if value.has_spec?
        @on_exit&.call(value)
      end
      
      def api_cloud_nexus_v1_endpoint_spec(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.description) if value.has_description?
        @on_exit&.call(value)
      end
      
      def api_cloud_operation_v1_async_operation(value)
        @on_enter&.call(value)
        google_protobuf_any(value.operation_input) if value.has_operation_input?
        @on_exit&.call(value)
      end
      
      def api_command_v1_cancel_workflow_execution_command_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_command_v1_command(value)
        @on_enter&.call(value)
        api_sdk_v1_user_metadata(value.user_metadata) if value.has_user_metadata?
        api_command_v1_schedule_activity_task_command_attributes(value.schedule_activity_task_command_attributes) if value.has_schedule_activity_task_command_attributes?
        api_command_v1_complete_workflow_execution_command_attributes(value.complete_workflow_execution_command_attributes) if value.has_complete_workflow_execution_command_attributes?
        api_command_v1_fail_workflow_execution_command_attributes(value.fail_workflow_execution_command_attributes) if value.has_fail_workflow_execution_command_attributes?
        api_command_v1_cancel_workflow_execution_command_attributes(value.cancel_workflow_execution_command_attributes) if value.has_cancel_workflow_execution_command_attributes?
        api_command_v1_record_marker_command_attributes(value.record_marker_command_attributes) if value.has_record_marker_command_attributes?
        api_command_v1_continue_as_new_workflow_execution_command_attributes(value.continue_as_new_workflow_execution_command_attributes) if value.has_continue_as_new_workflow_execution_command_attributes?
        api_command_v1_start_child_workflow_execution_command_attributes(value.start_child_workflow_execution_command_attributes) if value.has_start_child_workflow_execution_command_attributes?
        api_command_v1_signal_external_workflow_execution_command_attributes(value.signal_external_workflow_execution_command_attributes) if value.has_signal_external_workflow_execution_command_attributes?
        api_command_v1_upsert_workflow_search_attributes_command_attributes(value.upsert_workflow_search_attributes_command_attributes) if value.has_upsert_workflow_search_attributes_command_attributes?
        api_command_v1_modify_workflow_properties_command_attributes(value.modify_workflow_properties_command_attributes) if value.has_modify_workflow_properties_command_attributes?
        api_command_v1_schedule_nexus_operation_command_attributes(value.schedule_nexus_operation_command_attributes) if value.has_schedule_nexus_operation_command_attributes?
        @on_exit&.call(value)
      end
      
      def api_command_v1_complete_workflow_execution_command_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def api_command_v1_continue_as_new_workflow_execution_command_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_failure_v1_failure(value.failure) if value.has_failure?
        api_common_v1_payloads(value.last_completion_result) if value.has_last_completion_result?
        api_common_v1_header(value.header) if value.has_header?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_command_v1_fail_workflow_execution_command_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_command_v1_modify_workflow_properties_command_attributes(value)
        @on_enter&.call(value)
        api_common_v1_memo(value.upserted_memo) if value.has_upserted_memo?
        @on_exit&.call(value)
      end
      
      def api_command_v1_record_marker_command_attributes(value)
        @on_enter&.call(value)
        value.details.values.each { |v| api_common_v1_payloads(v) }
        api_common_v1_header(value.header) if value.has_header?
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_command_v1_schedule_activity_task_command_attributes(value)
        @on_enter&.call(value)
        api_common_v1_header(value.header) if value.has_header?
        api_common_v1_payloads(value.input) if value.has_input?
        @on_exit&.call(value)
      end
      
      def api_command_v1_schedule_nexus_operation_command_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.input) if value.has_input?
        @on_exit&.call(value)
      end
      
      def api_command_v1_signal_external_workflow_execution_command_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_header(value.header) if value.has_header?
        @on_exit&.call(value)
      end
      
      def api_command_v1_start_child_workflow_execution_command_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_header(value.header) if value.has_header?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_command_v1_upsert_workflow_search_attributes_command_attributes(value)
        @on_enter&.call(value)
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_common_v1_header(value)
        @on_enter&.call(value)
        value.fields.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def api_common_v1_memo(value)
        @on_enter&.call(value)
        value.fields.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def api_common_v1_payloads(value)
        @on_enter&.call(value)
        api_common_v1_payload_repeated(value.payloads) unless value.payloads.empty?
        @on_exit&.call(value)
      end
      
      def api_common_v1_search_attributes(value)
        return if @skip_search_attributes
        @on_enter&.call(value)
        value.indexed_fields.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def api_deployment_v1_deployment_info(value)
        @on_enter&.call(value)
        value.metadata.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def api_deployment_v1_update_deployment_metadata(value)
        @on_enter&.call(value)
        value.upsert_entries.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def api_deployment_v1_version_metadata(value)
        @on_enter&.call(value)
        value.entries.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def api_deployment_v1_worker_deployment_version_info(value)
        @on_enter&.call(value)
        api_deployment_v1_version_metadata(value.metadata) if value.has_metadata?
        @on_exit&.call(value)
      end
      
      def api_export_v1_workflow_execution(value)
        @on_enter&.call(value)
        api_history_v1_history(value.history) if value.has_history?
        @on_exit&.call(value)
      end
      
      def api_export_v1_workflow_executions(value)
        @on_enter&.call(value)
        value.items.each { |v| api_export_v1_workflow_execution(v) }
        @on_exit&.call(value)
      end
      
      def api_failure_v1_application_failure_info(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_failure_v1_canceled_failure_info(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_failure_v1_failure(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.encoded_attributes) if value.has_encoded_attributes?
        api_failure_v1_failure(value.cause) if value.has_cause?
        api_failure_v1_application_failure_info(value.application_failure_info) if value.has_application_failure_info?
        api_failure_v1_timeout_failure_info(value.timeout_failure_info) if value.has_timeout_failure_info?
        api_failure_v1_canceled_failure_info(value.canceled_failure_info) if value.has_canceled_failure_info?
        api_failure_v1_reset_workflow_failure_info(value.reset_workflow_failure_info) if value.has_reset_workflow_failure_info?
        @on_exit&.call(value)
      end
      
      def api_failure_v1_reset_workflow_failure_info(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.last_heartbeat_details) if value.has_last_heartbeat_details?
        @on_exit&.call(value)
      end
      
      def api_failure_v1_timeout_failure_info(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.last_heartbeat_details) if value.has_last_heartbeat_details?
        @on_exit&.call(value)
      end
      
      def api_history_v1_activity_task_canceled_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_history_v1_activity_task_completed_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def api_history_v1_activity_task_failed_event_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_activity_task_scheduled_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_header(value.header) if value.has_header?
        api_common_v1_payloads(value.input) if value.has_input?
        @on_exit&.call(value)
      end
      
      def api_history_v1_activity_task_started_event_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.last_failure) if value.has_last_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_activity_task_timed_out_event_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_child_workflow_execution_canceled_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_history_v1_child_workflow_execution_completed_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def api_history_v1_child_workflow_execution_failed_event_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_child_workflow_execution_started_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_header(value.header) if value.has_header?
        @on_exit&.call(value)
      end
      
      def api_history_v1_history(value)
        @on_enter&.call(value)
        value.events.each { |v| api_history_v1_history_event(v) }
        @on_exit&.call(value)
      end
      
      def api_history_v1_history_event(value)
        @on_enter&.call(value)
        api_sdk_v1_user_metadata(value.user_metadata) if value.has_user_metadata?
        api_history_v1_workflow_execution_started_event_attributes(value.workflow_execution_started_event_attributes) if value.has_workflow_execution_started_event_attributes?
        api_history_v1_workflow_execution_completed_event_attributes(value.workflow_execution_completed_event_attributes) if value.has_workflow_execution_completed_event_attributes?
        api_history_v1_workflow_execution_failed_event_attributes(value.workflow_execution_failed_event_attributes) if value.has_workflow_execution_failed_event_attributes?
        api_history_v1_workflow_task_failed_event_attributes(value.workflow_task_failed_event_attributes) if value.has_workflow_task_failed_event_attributes?
        api_history_v1_activity_task_scheduled_event_attributes(value.activity_task_scheduled_event_attributes) if value.has_activity_task_scheduled_event_attributes?
        api_history_v1_activity_task_started_event_attributes(value.activity_task_started_event_attributes) if value.has_activity_task_started_event_attributes?
        api_history_v1_activity_task_completed_event_attributes(value.activity_task_completed_event_attributes) if value.has_activity_task_completed_event_attributes?
        api_history_v1_activity_task_failed_event_attributes(value.activity_task_failed_event_attributes) if value.has_activity_task_failed_event_attributes?
        api_history_v1_activity_task_timed_out_event_attributes(value.activity_task_timed_out_event_attributes) if value.has_activity_task_timed_out_event_attributes?
        api_history_v1_activity_task_canceled_event_attributes(value.activity_task_canceled_event_attributes) if value.has_activity_task_canceled_event_attributes?
        api_history_v1_marker_recorded_event_attributes(value.marker_recorded_event_attributes) if value.has_marker_recorded_event_attributes?
        api_history_v1_workflow_execution_signaled_event_attributes(value.workflow_execution_signaled_event_attributes) if value.has_workflow_execution_signaled_event_attributes?
        api_history_v1_workflow_execution_terminated_event_attributes(value.workflow_execution_terminated_event_attributes) if value.has_workflow_execution_terminated_event_attributes?
        api_history_v1_workflow_execution_canceled_event_attributes(value.workflow_execution_canceled_event_attributes) if value.has_workflow_execution_canceled_event_attributes?
        api_history_v1_workflow_execution_continued_as_new_event_attributes(value.workflow_execution_continued_as_new_event_attributes) if value.has_workflow_execution_continued_as_new_event_attributes?
        api_history_v1_start_child_workflow_execution_initiated_event_attributes(value.start_child_workflow_execution_initiated_event_attributes) if value.has_start_child_workflow_execution_initiated_event_attributes?
        api_history_v1_child_workflow_execution_started_event_attributes(value.child_workflow_execution_started_event_attributes) if value.has_child_workflow_execution_started_event_attributes?
        api_history_v1_child_workflow_execution_completed_event_attributes(value.child_workflow_execution_completed_event_attributes) if value.has_child_workflow_execution_completed_event_attributes?
        api_history_v1_child_workflow_execution_failed_event_attributes(value.child_workflow_execution_failed_event_attributes) if value.has_child_workflow_execution_failed_event_attributes?
        api_history_v1_child_workflow_execution_canceled_event_attributes(value.child_workflow_execution_canceled_event_attributes) if value.has_child_workflow_execution_canceled_event_attributes?
        api_history_v1_signal_external_workflow_execution_initiated_event_attributes(value.signal_external_workflow_execution_initiated_event_attributes) if value.has_signal_external_workflow_execution_initiated_event_attributes?
        api_history_v1_upsert_workflow_search_attributes_event_attributes(value.upsert_workflow_search_attributes_event_attributes) if value.has_upsert_workflow_search_attributes_event_attributes?
        api_history_v1_workflow_execution_update_accepted_event_attributes(value.workflow_execution_update_accepted_event_attributes) if value.has_workflow_execution_update_accepted_event_attributes?
        api_history_v1_workflow_execution_update_rejected_event_attributes(value.workflow_execution_update_rejected_event_attributes) if value.has_workflow_execution_update_rejected_event_attributes?
        api_history_v1_workflow_execution_update_completed_event_attributes(value.workflow_execution_update_completed_event_attributes) if value.has_workflow_execution_update_completed_event_attributes?
        api_history_v1_workflow_properties_modified_externally_event_attributes(value.workflow_properties_modified_externally_event_attributes) if value.has_workflow_properties_modified_externally_event_attributes?
        api_history_v1_workflow_properties_modified_event_attributes(value.workflow_properties_modified_event_attributes) if value.has_workflow_properties_modified_event_attributes?
        api_history_v1_workflow_execution_update_admitted_event_attributes(value.workflow_execution_update_admitted_event_attributes) if value.has_workflow_execution_update_admitted_event_attributes?
        api_history_v1_nexus_operation_scheduled_event_attributes(value.nexus_operation_scheduled_event_attributes) if value.has_nexus_operation_scheduled_event_attributes?
        api_history_v1_nexus_operation_completed_event_attributes(value.nexus_operation_completed_event_attributes) if value.has_nexus_operation_completed_event_attributes?
        api_history_v1_nexus_operation_failed_event_attributes(value.nexus_operation_failed_event_attributes) if value.has_nexus_operation_failed_event_attributes?
        api_history_v1_nexus_operation_canceled_event_attributes(value.nexus_operation_canceled_event_attributes) if value.has_nexus_operation_canceled_event_attributes?
        api_history_v1_nexus_operation_timed_out_event_attributes(value.nexus_operation_timed_out_event_attributes) if value.has_nexus_operation_timed_out_event_attributes?
        api_history_v1_nexus_operation_cancel_request_failed_event_attributes(value.nexus_operation_cancel_request_failed_event_attributes) if value.has_nexus_operation_cancel_request_failed_event_attributes?
        @on_exit&.call(value)
      end
      
      def api_history_v1_marker_recorded_event_attributes(value)
        @on_enter&.call(value)
        value.details.values.each { |v| api_common_v1_payloads(v) }
        api_common_v1_header(value.header) if value.has_header?
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_nexus_operation_cancel_request_failed_event_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_nexus_operation_canceled_event_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_nexus_operation_completed_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def api_history_v1_nexus_operation_failed_event_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_nexus_operation_scheduled_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.input) if value.has_input?
        @on_exit&.call(value)
      end
      
      def api_history_v1_nexus_operation_timed_out_event_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_signal_external_workflow_execution_initiated_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_header(value.header) if value.has_header?
        @on_exit&.call(value)
      end
      
      def api_history_v1_start_child_workflow_execution_initiated_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_header(value.header) if value.has_header?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_history_v1_upsert_workflow_search_attributes_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_canceled_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_completed_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_continued_as_new_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_failure_v1_failure(value.failure) if value.has_failure?
        api_common_v1_payloads(value.last_completion_result) if value.has_last_completion_result?
        api_common_v1_header(value.header) if value.has_header?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_failed_event_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_signaled_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_header(value.header) if value.has_header?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_started_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_failure_v1_failure(value.continued_failure) if value.has_continued_failure?
        api_common_v1_payloads(value.last_completion_result) if value.has_last_completion_result?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        api_common_v1_header(value.header) if value.has_header?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_terminated_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_update_accepted_event_attributes(value)
        @on_enter&.call(value)
        api_update_v1_request(value.accepted_request) if value.has_accepted_request?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_update_admitted_event_attributes(value)
        @on_enter&.call(value)
        api_update_v1_request(value.request) if value.has_request?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_update_completed_event_attributes(value)
        @on_enter&.call(value)
        api_update_v1_outcome(value.outcome) if value.has_outcome?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_execution_update_rejected_event_attributes(value)
        @on_enter&.call(value)
        api_update_v1_request(value.rejected_request) if value.has_rejected_request?
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_properties_modified_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_memo(value.upserted_memo) if value.has_upserted_memo?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_properties_modified_externally_event_attributes(value)
        @on_enter&.call(value)
        api_common_v1_memo(value.upserted_memo) if value.has_upserted_memo?
        @on_exit&.call(value)
      end
      
      def api_history_v1_workflow_task_failed_event_attributes(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_nexus_v1_endpoint(value)
        @on_enter&.call(value)
        api_nexus_v1_endpoint_spec(value.spec) if value.has_spec?
        @on_exit&.call(value)
      end
      
      def api_nexus_v1_endpoint_spec(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.description) if value.has_description?
        @on_exit&.call(value)
      end
      
      def api_nexus_v1_request(value)
        @on_enter&.call(value)
        api_nexus_v1_start_operation_request(value.start_operation) if value.has_start_operation?
        @on_exit&.call(value)
      end
      
      def api_nexus_v1_response(value)
        @on_enter&.call(value)
        api_nexus_v1_start_operation_response(value.start_operation) if value.has_start_operation?
        @on_exit&.call(value)
      end
      
      def api_nexus_v1_start_operation_request(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.payload) if value.has_payload?
        @on_exit&.call(value)
      end
      
      def api_nexus_v1_start_operation_response(value)
        @on_enter&.call(value)
        api_nexus_v1_start_operation_response_sync(value.sync_success) if value.has_sync_success?
        @on_exit&.call(value)
      end
      
      def api_nexus_v1_start_operation_response_sync(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.payload) if value.has_payload?
        @on_exit&.call(value)
      end
      
      def api_operatorservice_v1_create_nexus_endpoint_request(value)
        @on_enter&.call(value)
        api_nexus_v1_endpoint_spec(value.spec) if value.has_spec?
        @on_exit&.call(value)
      end
      
      def api_operatorservice_v1_create_nexus_endpoint_response(value)
        @on_enter&.call(value)
        api_nexus_v1_endpoint(value.endpoint) if value.has_endpoint?
        @on_exit&.call(value)
      end
      
      def api_operatorservice_v1_get_nexus_endpoint_response(value)
        @on_enter&.call(value)
        api_nexus_v1_endpoint(value.endpoint) if value.has_endpoint?
        @on_exit&.call(value)
      end
      
      def api_operatorservice_v1_list_nexus_endpoints_response(value)
        @on_enter&.call(value)
        value.endpoints.each { |v| api_nexus_v1_endpoint(v) }
        @on_exit&.call(value)
      end
      
      def api_operatorservice_v1_update_nexus_endpoint_request(value)
        @on_enter&.call(value)
        api_nexus_v1_endpoint_spec(value.spec) if value.has_spec?
        @on_exit&.call(value)
      end
      
      def api_operatorservice_v1_update_nexus_endpoint_response(value)
        @on_enter&.call(value)
        api_nexus_v1_endpoint(value.endpoint) if value.has_endpoint?
        @on_exit&.call(value)
      end
      
      def api_protocol_v1_message(value)
        @on_enter&.call(value)
        google_protobuf_any(value.body) if value.has_body?
        @on_exit&.call(value)
      end
      
      def api_query_v1_workflow_query(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.query_args) if value.has_query_args?
        api_common_v1_header(value.header) if value.has_header?
        @on_exit&.call(value)
      end
      
      def api_query_v1_workflow_query_result(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.answer) if value.has_answer?
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_schedule_v1_schedule(value)
        @on_enter&.call(value)
        api_schedule_v1_schedule_action(value.action) if value.has_action?
        @on_exit&.call(value)
      end
      
      def api_schedule_v1_schedule_action(value)
        @on_enter&.call(value)
        api_workflow_v1_new_workflow_execution_info(value.start_workflow) if value.has_start_workflow?
        @on_exit&.call(value)
      end
      
      def api_schedule_v1_schedule_list_entry(value)
        @on_enter&.call(value)
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_sdk_v1_user_metadata(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.summary) if value.has_summary?
        api_common_v1_payload(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_update_v1_input(value)
        @on_enter&.call(value)
        api_common_v1_header(value.header) if value.has_header?
        api_common_v1_payloads(value.args) if value.has_args?
        @on_exit&.call(value)
      end
      
      def api_update_v1_outcome(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.success) if value.has_success?
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_update_v1_request(value)
        @on_enter&.call(value)
        api_update_v1_input(value.input) if value.has_input?
        @on_exit&.call(value)
      end
      
      def api_workflow_v1_callback_info(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.last_attempt_failure) if value.has_last_attempt_failure?
        @on_exit&.call(value)
      end
      
      def api_workflow_v1_new_workflow_execution_info(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        api_common_v1_header(value.header) if value.has_header?
        api_sdk_v1_user_metadata(value.user_metadata) if value.has_user_metadata?
        @on_exit&.call(value)
      end
      
      def api_workflow_v1_nexus_operation_cancellation_info(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.last_attempt_failure) if value.has_last_attempt_failure?
        @on_exit&.call(value)
      end
      
      def api_workflow_v1_pending_activity_info(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.heartbeat_details) if value.has_heartbeat_details?
        api_failure_v1_failure(value.last_failure) if value.has_last_failure?
        @on_exit&.call(value)
      end
      
      def api_workflow_v1_pending_nexus_operation_info(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.last_attempt_failure) if value.has_last_attempt_failure?
        api_workflow_v1_nexus_operation_cancellation_info(value.cancellation_info) if value.has_cancellation_info?
        @on_exit&.call(value)
      end
      
      def api_workflow_v1_post_reset_operation(value)
        @on_enter&.call(value)
        api_workflow_v1_post_reset_operation_signal_workflow(value.signal_workflow) if value.has_signal_workflow?
        @on_exit&.call(value)
      end
      
      def api_workflow_v1_post_reset_operation_signal_workflow(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_header(value.header) if value.has_header?
        @on_exit&.call(value)
      end
      
      def api_workflow_v1_workflow_execution_config(value)
        @on_enter&.call(value)
        api_sdk_v1_user_metadata(value.user_metadata) if value.has_user_metadata?
        @on_exit&.call(value)
      end
      
      def api_workflow_v1_workflow_execution_info(value)
        @on_enter&.call(value)
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_count_workflow_executions_response(value)
        @on_enter&.call(value)
        value.groups.each { |v| api_workflowservice_v1_count_workflow_executions_response_aggregation_group(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_count_workflow_executions_response_aggregation_group(value)
        @on_enter&.call(value)
        api_common_v1_payload_repeated(value.group_values) unless value.group_values.empty?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_create_schedule_request(value)
        @on_enter&.call(value)
        api_schedule_v1_schedule(value.schedule) if value.has_schedule?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_describe_deployment_response(value)
        @on_enter&.call(value)
        api_deployment_v1_deployment_info(value.deployment_info) if value.has_deployment_info?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_describe_schedule_response(value)
        @on_enter&.call(value)
        api_schedule_v1_schedule(value.schedule) if value.has_schedule?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_describe_worker_deployment_version_response(value)
        @on_enter&.call(value)
        api_deployment_v1_worker_deployment_version_info(value.worker_deployment_version_info) if value.has_worker_deployment_version_info?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_describe_workflow_execution_response(value)
        @on_enter&.call(value)
        api_workflow_v1_workflow_execution_config(value.execution_config) if value.has_execution_config?
        api_workflow_v1_workflow_execution_info(value.workflow_execution_info) if value.has_workflow_execution_info?
        value.pending_activities.each { |v| api_workflow_v1_pending_activity_info(v) }
        value.callbacks.each { |v| api_workflow_v1_callback_info(v) }
        value.pending_nexus_operations.each { |v| api_workflow_v1_pending_nexus_operation_info(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_execute_multi_operation_request(value)
        @on_enter&.call(value)
        value.operations.each { |v| api_workflowservice_v1_execute_multi_operation_request_operation(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_execute_multi_operation_request_operation(value)
        @on_enter&.call(value)
        api_workflowservice_v1_start_workflow_execution_request(value.start_workflow) if value.has_start_workflow?
        api_workflowservice_v1_update_workflow_execution_request(value.update_workflow) if value.has_update_workflow?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_execute_multi_operation_response(value)
        @on_enter&.call(value)
        value.responses.each { |v| api_workflowservice_v1_execute_multi_operation_response_response(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_execute_multi_operation_response_response(value)
        @on_enter&.call(value)
        api_workflowservice_v1_start_workflow_execution_response(value.start_workflow) if value.has_start_workflow?
        api_workflowservice_v1_update_workflow_execution_response(value.update_workflow) if value.has_update_workflow?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_get_current_deployment_response(value)
        @on_enter&.call(value)
        api_deployment_v1_deployment_info(value.current_deployment_info) if value.has_current_deployment_info?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_get_deployment_reachability_response(value)
        @on_enter&.call(value)
        api_deployment_v1_deployment_info(value.deployment_info) if value.has_deployment_info?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_get_workflow_execution_history_response(value)
        @on_enter&.call(value)
        api_history_v1_history(value.history) if value.has_history?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_get_workflow_execution_history_reverse_response(value)
        @on_enter&.call(value)
        api_history_v1_history(value.history) if value.has_history?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_list_archived_workflow_executions_response(value)
        @on_enter&.call(value)
        value.executions.each { |v| api_workflow_v1_workflow_execution_info(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_list_closed_workflow_executions_response(value)
        @on_enter&.call(value)
        value.executions.each { |v| api_workflow_v1_workflow_execution_info(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_list_open_workflow_executions_response(value)
        @on_enter&.call(value)
        value.executions.each { |v| api_workflow_v1_workflow_execution_info(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_list_schedules_response(value)
        @on_enter&.call(value)
        value.schedules.each { |v| api_schedule_v1_schedule_list_entry(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_list_workflow_executions_response(value)
        @on_enter&.call(value)
        value.executions.each { |v| api_workflow_v1_workflow_execution_info(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_poll_activity_task_queue_response(value)
        @on_enter&.call(value)
        api_common_v1_header(value.header) if value.has_header?
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_payloads(value.heartbeat_details) if value.has_heartbeat_details?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_poll_nexus_task_queue_response(value)
        @on_enter&.call(value)
        api_nexus_v1_request(value.request) if value.has_request?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_poll_workflow_execution_update_response(value)
        @on_enter&.call(value)
        api_update_v1_outcome(value.outcome) if value.has_outcome?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_poll_workflow_task_queue_response(value)
        @on_enter&.call(value)
        api_history_v1_history(value.history) if value.has_history?
        api_query_v1_workflow_query(value.query) if value.has_query?
        value.queries.values.each { |v| api_query_v1_workflow_query(v) }
        value.messages.each { |v| api_protocol_v1_message(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_query_workflow_request(value)
        @on_enter&.call(value)
        api_query_v1_workflow_query(value.query) if value.has_query?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_query_workflow_response(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.query_result) if value.has_query_result?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_record_activity_task_heartbeat_by_id_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_record_activity_task_heartbeat_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_reset_workflow_execution_request(value)
        @on_enter&.call(value)
        value.post_reset_operations.each { |v| api_workflow_v1_post_reset_operation(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_activity_task_canceled_by_id_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_activity_task_canceled_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_activity_task_completed_by_id_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_activity_task_completed_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_activity_task_failed_by_id_request(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        api_common_v1_payloads(value.last_heartbeat_details) if value.has_last_heartbeat_details?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_activity_task_failed_by_id_response(value)
        @on_enter&.call(value)
        value.failures.each { |v| api_failure_v1_failure(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_activity_task_failed_request(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        api_common_v1_payloads(value.last_heartbeat_details) if value.has_last_heartbeat_details?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_activity_task_failed_response(value)
        @on_enter&.call(value)
        value.failures.each { |v| api_failure_v1_failure(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_nexus_task_completed_request(value)
        @on_enter&.call(value)
        api_nexus_v1_response(value.response) if value.has_response?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_query_task_completed_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.query_result) if value.has_query_result?
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_workflow_task_completed_request(value)
        @on_enter&.call(value)
        value.commands.each { |v| api_command_v1_command(v) }
        value.query_results.values.each { |v| api_query_v1_workflow_query_result(v) }
        value.messages.each { |v| api_protocol_v1_message(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_workflow_task_completed_response(value)
        @on_enter&.call(value)
        api_workflowservice_v1_poll_workflow_task_queue_response(value.workflow_task) if value.has_workflow_task?
        value.activity_tasks.each { |v| api_workflowservice_v1_poll_activity_task_queue_response(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_respond_workflow_task_failed_request(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        value.messages.each { |v| api_protocol_v1_message(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_scan_workflow_executions_response(value)
        @on_enter&.call(value)
        value.executions.each { |v| api_workflow_v1_workflow_execution_info(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_set_current_deployment_request(value)
        @on_enter&.call(value)
        api_deployment_v1_update_deployment_metadata(value.update_metadata) if value.has_update_metadata?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_set_current_deployment_response(value)
        @on_enter&.call(value)
        api_deployment_v1_deployment_info(value.current_deployment_info) if value.has_current_deployment_info?
        api_deployment_v1_deployment_info(value.previous_deployment_info) if value.has_previous_deployment_info?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_signal_with_start_workflow_execution_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_payloads(value.signal_input) if value.has_signal_input?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        api_common_v1_header(value.header) if value.has_header?
        api_sdk_v1_user_metadata(value.user_metadata) if value.has_user_metadata?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_signal_workflow_execution_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_header(value.header) if value.has_header?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_start_batch_operation_request(value)
        @on_enter&.call(value)
        api_batch_v1_batch_operation_termination(value.termination_operation) if value.has_termination_operation?
        api_batch_v1_batch_operation_signal(value.signal_operation) if value.has_signal_operation?
        api_batch_v1_batch_operation_reset(value.reset_operation) if value.has_reset_operation?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_start_workflow_execution_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.input) if value.has_input?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        api_common_v1_header(value.header) if value.has_header?
        api_failure_v1_failure(value.continued_failure) if value.has_continued_failure?
        api_common_v1_payloads(value.last_completion_result) if value.has_last_completion_result?
        api_sdk_v1_user_metadata(value.user_metadata) if value.has_user_metadata?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_start_workflow_execution_response(value)
        @on_enter&.call(value)
        api_workflowservice_v1_poll_workflow_task_queue_response(value.eager_workflow_task) if value.has_eager_workflow_task?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_terminate_workflow_execution_request(value)
        @on_enter&.call(value)
        api_common_v1_payloads(value.details) if value.has_details?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_update_schedule_request(value)
        @on_enter&.call(value)
        api_schedule_v1_schedule(value.schedule) if value.has_schedule?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_update_worker_deployment_version_metadata_request(value)
        @on_enter&.call(value)
        value.upsert_entries.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_update_worker_deployment_version_metadata_response(value)
        @on_enter&.call(value)
        api_deployment_v1_version_metadata(value.metadata) if value.has_metadata?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_update_workflow_execution_request(value)
        @on_enter&.call(value)
        api_update_v1_request(value.request) if value.has_request?
        @on_exit&.call(value)
      end
      
      def api_workflowservice_v1_update_workflow_execution_response(value)
        @on_enter&.call(value)
        api_update_v1_outcome(value.outcome) if value.has_outcome?
        @on_exit&.call(value)
      end
      
      def coresdk_activity_result_activity_resolution(value)
        @on_enter&.call(value)
        coresdk_activity_result_success(value.completed) if value.has_completed?
        coresdk_activity_result_failure(value.failed) if value.has_failed?
        coresdk_activity_result_cancellation(value.cancelled) if value.has_cancelled?
        @on_exit&.call(value)
      end
      
      def coresdk_activity_result_cancellation(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def coresdk_activity_result_failure(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def coresdk_activity_result_success(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def coresdk_child_workflow_cancellation(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def coresdk_child_workflow_child_workflow_result(value)
        @on_enter&.call(value)
        coresdk_child_workflow_success(value.completed) if value.has_completed?
        coresdk_child_workflow_failure(value.failed) if value.has_failed?
        coresdk_child_workflow_cancellation(value.cancelled) if value.has_cancelled?
        @on_exit&.call(value)
      end
      
      def coresdk_child_workflow_failure(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def coresdk_child_workflow_success(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def coresdk_nexus_nexus_operation_result(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.completed) if value.has_completed?
        api_failure_v1_failure(value.failed) if value.has_failed?
        api_failure_v1_failure(value.cancelled) if value.has_cancelled?
        api_failure_v1_failure(value.timed_out) if value.has_timed_out?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_do_update(value)
        @on_enter&.call(value)
        api_common_v1_payload_repeated(value.input) unless value.input.empty?
        value.headers.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_initialize_workflow(value)
        @on_enter&.call(value)
        api_common_v1_payload_repeated(value.arguments) unless value.arguments.empty?
        value.headers.values.each { |v| api_common_v1_payload(v) }
        api_failure_v1_failure(value.continued_failure) if value.has_continued_failure?
        api_common_v1_payloads(value.last_completion_result) if value.has_last_completion_result?
        api_common_v1_memo(value.memo) if value.has_memo?
        api_common_v1_search_attributes(value.search_attributes) if value.has_search_attributes?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_query_workflow(value)
        @on_enter&.call(value)
        api_common_v1_payload_repeated(value.arguments) unless value.arguments.empty?
        value.headers.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_resolve_activity(value)
        @on_enter&.call(value)
        coresdk_activity_result_activity_resolution(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_resolve_child_workflow_execution(value)
        @on_enter&.call(value)
        coresdk_child_workflow_child_workflow_result(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_resolve_child_workflow_execution_start(value)
        @on_enter&.call(value)
        coresdk_workflow_activation_resolve_child_workflow_execution_start_cancelled(value.cancelled) if value.has_cancelled?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_resolve_child_workflow_execution_start_cancelled(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_resolve_nexus_operation(value)
        @on_enter&.call(value)
        coresdk_nexus_nexus_operation_result(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_resolve_nexus_operation_start(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failed) if value.has_failed?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_resolve_request_cancel_external_workflow(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_resolve_signal_external_workflow(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_signal_workflow(value)
        @on_enter&.call(value)
        api_common_v1_payload_repeated(value.input) unless value.input.empty?
        value.headers.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_workflow_activation(value)
        @on_enter&.call(value)
        value.jobs.each { |v| coresdk_workflow_activation_workflow_activation_job(v) }
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_activation_workflow_activation_job(value)
        @on_enter&.call(value)
        coresdk_workflow_activation_initialize_workflow(value.initialize_workflow) if value.has_initialize_workflow?
        coresdk_workflow_activation_query_workflow(value.query_workflow) if value.has_query_workflow?
        coresdk_workflow_activation_signal_workflow(value.signal_workflow) if value.has_signal_workflow?
        coresdk_workflow_activation_resolve_activity(value.resolve_activity) if value.has_resolve_activity?
        coresdk_workflow_activation_resolve_child_workflow_execution_start(value.resolve_child_workflow_execution_start) if value.has_resolve_child_workflow_execution_start?
        coresdk_workflow_activation_resolve_child_workflow_execution(value.resolve_child_workflow_execution) if value.has_resolve_child_workflow_execution?
        coresdk_workflow_activation_resolve_signal_external_workflow(value.resolve_signal_external_workflow) if value.has_resolve_signal_external_workflow?
        coresdk_workflow_activation_resolve_request_cancel_external_workflow(value.resolve_request_cancel_external_workflow) if value.has_resolve_request_cancel_external_workflow?
        coresdk_workflow_activation_do_update(value.do_update) if value.has_do_update?
        coresdk_workflow_activation_resolve_nexus_operation_start(value.resolve_nexus_operation_start) if value.has_resolve_nexus_operation_start?
        coresdk_workflow_activation_resolve_nexus_operation(value.resolve_nexus_operation) if value.has_resolve_nexus_operation?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_complete_workflow_execution(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.result) if value.has_result?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_continue_as_new_workflow_execution(value)
        @on_enter&.call(value)
        api_common_v1_payload_repeated(value.arguments) unless value.arguments.empty?
        value.memo.values.each { |v| api_common_v1_payload(v) }
        value.headers.values.each { |v| api_common_v1_payload(v) }
        value.search_attributes.values.each { |v| api_common_v1_payload(v) } unless @skip_search_attributes
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_fail_workflow_execution(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_modify_workflow_properties(value)
        @on_enter&.call(value)
        api_common_v1_memo(value.upserted_memo) if value.has_upserted_memo?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_query_result(value)
        @on_enter&.call(value)
        coresdk_workflow_commands_query_success(value.succeeded) if value.has_succeeded?
        api_failure_v1_failure(value.failed) if value.has_failed?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_query_success(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.response) if value.has_response?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_schedule_activity(value)
        @on_enter&.call(value)
        value.headers.values.each { |v| api_common_v1_payload(v) }
        api_common_v1_payload_repeated(value.arguments) unless value.arguments.empty?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_schedule_local_activity(value)
        @on_enter&.call(value)
        value.headers.values.each { |v| api_common_v1_payload(v) }
        api_common_v1_payload_repeated(value.arguments) unless value.arguments.empty?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_schedule_nexus_operation(value)
        @on_enter&.call(value)
        api_common_v1_payload(value.input) if value.has_input?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_signal_external_workflow_execution(value)
        @on_enter&.call(value)
        api_common_v1_payload_repeated(value.args) unless value.args.empty?
        value.headers.values.each { |v| api_common_v1_payload(v) }
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_start_child_workflow_execution(value)
        @on_enter&.call(value)
        api_common_v1_payload_repeated(value.input) unless value.input.empty?
        value.headers.values.each { |v| api_common_v1_payload(v) }
        value.memo.values.each { |v| api_common_v1_payload(v) }
        value.search_attributes.values.each { |v| api_common_v1_payload(v) } unless @skip_search_attributes
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_update_response(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.rejected) if value.has_rejected?
        api_common_v1_payload(value.completed) if value.has_completed?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_upsert_workflow_search_attributes(value)
        @on_enter&.call(value)
        value.search_attributes.values.each { |v| api_common_v1_payload(v) } unless @skip_search_attributes
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_commands_workflow_command(value)
        @on_enter&.call(value)
        api_sdk_v1_user_metadata(value.user_metadata) if value.has_user_metadata?
        coresdk_workflow_commands_schedule_activity(value.schedule_activity) if value.has_schedule_activity?
        coresdk_workflow_commands_query_result(value.respond_to_query) if value.has_respond_to_query?
        coresdk_workflow_commands_complete_workflow_execution(value.complete_workflow_execution) if value.has_complete_workflow_execution?
        coresdk_workflow_commands_fail_workflow_execution(value.fail_workflow_execution) if value.has_fail_workflow_execution?
        coresdk_workflow_commands_continue_as_new_workflow_execution(value.continue_as_new_workflow_execution) if value.has_continue_as_new_workflow_execution?
        coresdk_workflow_commands_start_child_workflow_execution(value.start_child_workflow_execution) if value.has_start_child_workflow_execution?
        coresdk_workflow_commands_signal_external_workflow_execution(value.signal_external_workflow_execution) if value.has_signal_external_workflow_execution?
        coresdk_workflow_commands_schedule_local_activity(value.schedule_local_activity) if value.has_schedule_local_activity?
        coresdk_workflow_commands_upsert_workflow_search_attributes(value.upsert_workflow_search_attributes) if value.has_upsert_workflow_search_attributes?
        coresdk_workflow_commands_modify_workflow_properties(value.modify_workflow_properties) if value.has_modify_workflow_properties?
        coresdk_workflow_commands_update_response(value.update_response) if value.has_update_response?
        coresdk_workflow_commands_schedule_nexus_operation(value.schedule_nexus_operation) if value.has_schedule_nexus_operation?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_completion_failure(value)
        @on_enter&.call(value)
        api_failure_v1_failure(value.failure) if value.has_failure?
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_completion_success(value)
        @on_enter&.call(value)
        value.commands.each { |v| coresdk_workflow_commands_workflow_command(v) }
        @on_exit&.call(value)
      end
      
      def coresdk_workflow_completion_workflow_activation_completion(value)
        @on_enter&.call(value)
        coresdk_workflow_completion_success(value.successful) if value.has_successful?
        coresdk_workflow_completion_failure(value.failed) if value.has_failed?
        @on_exit&.call(value)
      end
    end
  end
end
