# frozen_string_literal: true

require 'google/protobuf/well_known_types'
require 'securerandom'
require 'temporalio/api'
require 'temporalio/client/activity_id_reference'
require 'temporalio/client/async_activity_handle'
require 'temporalio/client/connection'
require 'temporalio/client/interceptor'
require 'temporalio/client/schedule'
require 'temporalio/client/schedule_handle'
require 'temporalio/client/with_start_workflow_operation'
require 'temporalio/client/workflow_execution'
require 'temporalio/client/workflow_execution_count'
require 'temporalio/client/workflow_handle'
require 'temporalio/common_enums'
require 'temporalio/converters'
require 'temporalio/error'
require 'temporalio/error/failure'
require 'temporalio/internal/proto_utils'
require 'temporalio/runtime'
require 'temporalio/search_attributes'
require 'temporalio/workflow/definition'

module Temporalio
  module Internal
    module Client
      class Implementation < Temporalio::Client::Interceptor::Outbound
        require_relative 'implementation/list_workflow_page'

        def self.with_default_rpc_options(user_rpc_options)
          # If the user did not provide an override_retry, we need to make sure
          # we use an option set that has it as "true"
          if user_rpc_options.nil?
            user_rpc_options = @always_retry_options ||= Temporalio::Client::RPCOptions.new(override_retry: true)
          elsif !user_rpc_options.is_a?(Temporalio::Client::RPCOptions)
            raise ArgumentError, 'rpc_options must be RPCOptions'
          elsif user_rpc_options.override_retry.nil?
            # Copy and set as true
            user_rpc_options = user_rpc_options.dup
            user_rpc_options.override_retry = true
          end
          user_rpc_options
        end

        def initialize(client)
          super(nil) # steep:ignore
          @client = client
        end

        def start_workflow(input)
          req = Api::WorkflowService::V1::StartWorkflowExecutionRequest.new(
            request_id: SecureRandom.uuid,
            namespace: @client.namespace,
            workflow_type: Api::Common::V1::WorkflowType.new(name: input.workflow),
            workflow_id: input.workflow_id,
            task_queue: Api::TaskQueue::V1::TaskQueue.new(name: input.task_queue.to_s),
            input: @client.data_converter.to_payloads(input.args),
            workflow_execution_timeout: ProtoUtils.seconds_to_duration(input.execution_timeout),
            workflow_run_timeout: ProtoUtils.seconds_to_duration(input.run_timeout),
            workflow_task_timeout: ProtoUtils.seconds_to_duration(input.task_timeout),
            identity: @client.connection.identity,
            workflow_id_reuse_policy: input.id_reuse_policy,
            workflow_id_conflict_policy: input.id_conflict_policy,
            retry_policy: input.retry_policy&._to_proto,
            cron_schedule: input.cron_schedule,
            memo: ProtoUtils.memo_to_proto(input.memo, @client.data_converter),
            search_attributes: input.search_attributes&._to_proto,
            workflow_start_delay: ProtoUtils.seconds_to_duration(input.start_delay),
            request_eager_execution: input.request_eager_start,
            user_metadata: ProtoUtils.to_user_metadata(
              input.static_summary, input.static_details, @client.data_converter
            ),
            header: ProtoUtils.headers_to_proto(input.headers, @client.data_converter),
            priority: input.priority._to_proto,
            versioning_override: input.versioning_override&._to_proto
          )

          # Send request
          begin
            resp = @client.workflow_service.start_workflow_execution(
              req,
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
          rescue Error::RPCError => e
            # Unpack and raise already started if that's the error, otherwise default raise
            if e.code == Error::RPCError::Code::ALREADY_EXISTS && e.grpc_status.details.first
              details = e.grpc_status.details.first.unpack(
                Api::ErrorDetails::V1::WorkflowExecutionAlreadyStartedFailure
              )
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
          Temporalio::Client::WorkflowHandle.new(
            client: @client,
            id: input.workflow_id,
            run_id: nil,
            result_run_id: resp.run_id,
            first_execution_run_id: resp.run_id
          )
        end

        def start_update_with_start_workflow(input)
          raise ArgumentError, 'Start operation is required' unless input.start_workflow_operation

          if input.start_workflow_operation.options.id_conflict_policy == WorkflowIDConflictPolicy::UNSPECIFIED
            raise ArgumentError, 'ID conflict policy is required in start operation'
          end

          # Try to mark used before using
          input.start_workflow_operation._mark_used

          # Build request
          start_options = input.start_workflow_operation.options
          start_req = _start_workflow_request_from_with_start_options(
            Api::WorkflowService::V1::StartWorkflowExecutionRequest, start_options
          )
          req = Api::WorkflowService::V1::ExecuteMultiOperationRequest.new(
            namespace: @client.namespace,
            operations: [
              Api::WorkflowService::V1::ExecuteMultiOperationRequest::Operation.new(start_workflow: start_req),
              Api::WorkflowService::V1::ExecuteMultiOperationRequest::Operation.new(
                update_workflow: Api::WorkflowService::V1::UpdateWorkflowExecutionRequest.new(
                  namespace: @client.namespace,
                  workflow_execution: Api::Common::V1::WorkflowExecution.new(
                    workflow_id: start_options.id
                  ),
                  request: Api::Update::V1::Request.new(
                    meta: Api::Update::V1::Meta.new(
                      update_id: input.update_id,
                      identity: @client.connection.identity
                    ),
                    input: Api::Update::V1::Input.new(
                      name: input.update,
                      args: @client.data_converter.to_payloads(input.args),
                      header: Internal::ProtoUtils.headers_to_proto(input.headers, @client.data_converter)
                    )
                  ),
                  wait_policy: Api::Update::V1::WaitPolicy.new(
                    lifecycle_stage: input.wait_for_stage
                  )
                )
              )
            ]
          )

          # Continually try to start until an exception occurs, the user-asked stage is reached, or the stage is
          # accepted. But we will set the workflow handle as soon as we can.
          # @type var update_resp: untyped
          update_resp = nil
          run_id = nil
          begin
            loop do
              resp = @client.workflow_service.execute_multi_operation(
                req, rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
              )
              run_id = resp.responses.first.start_workflow.run_id
              # Set workflow handle (no-op if already set)
              input.start_workflow_operation._set_workflow_handle(
                Temporalio::Client::WorkflowHandle.new(
                  client: @client,
                  id: start_options.id,
                  run_id: nil,
                  result_run_id: run_id,
                  first_execution_run_id: run_id
                )
              )
              update_resp = resp.responses.last.update_workflow

              # We're only done if the response stage is at least accepted
              if update_resp && Api::Enums::V1::UpdateWorkflowExecutionLifecycleStage.resolve(update_resp.stage) >=
                                Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
                break
              end
            end

            # If the user wants to wait until completed, we must poll until outcome if not already there
            if input.wait_for_stage == Temporalio::Client::WorkflowUpdateWaitStage::COMPLETED && update_resp.outcome
              update_resp.outcome = @client._impl.poll_workflow_update(
                Temporalio::Client::Interceptor::PollWorkflowUpdateInput.new(
                  workflow_id: start_options.id,
                  run_id:,
                  update_id: input.update_id,
                  rpc_options: input.rpc_options
                )
              )
            end
          rescue Error => e
            # If this is a multi-operation failure, set exception to the first present, non-OK, non-aborted error
            if e.is_a?(Error::RPCError)
              multi_err = e.grpc_status.details&.first&.unpack(Api::ErrorDetails::V1::MultiOperationExecutionFailure)
              if multi_err
                non_aborted = multi_err.statuses.find do |s|
                  # Exists, not-ok, not-aborted
                  s && s.code != Error::RPCError::Code::OK &&
                    !s.details&.first&.is(Api::Failure::V1::MultiOperationExecutionAborted)
                end
                if non_aborted
                  e = Error::RPCError.new(
                    non_aborted.message,
                    code: non_aborted.code,
                    raw_grpc_status: Api::Common::V1::GrpcStatus.new(
                      code: non_aborted.code, message: non_aborted.message, details: non_aborted.details.to_a
                    )
                  )
                end
              end
            end
            if e.is_a?(Error::RPCError)
              # Deadline exceeded or cancel is a special error type
              if e.code == Error::RPCError::Code::DEADLINE_EXCEEDED || e.code == Error::RPCError::Code::CANCELED
                e = Error::WorkflowUpdateRPCTimeoutOrCanceledError.new
              elsif e.code == Error::RPCError::Code::ALREADY_EXISTS && e.grpc_status.details.first
                # Unpack and set already started if that's the error
                details = e.grpc_status.details.first.unpack(
                  Api::ErrorDetails::V1::WorkflowExecutionAlreadyStartedFailure
                )
                if details
                  e = Error::WorkflowAlreadyStartedError.new(
                    workflow_id: start_options.id,
                    workflow_type: start_req.workflow_type,
                    run_id: details.run_id
                  )
                end
              end
            end
            # Cancel is a special type
            e = Error::WorkflowUpdateRPCTimeoutOrCanceledError.new if e.is_a?(Error::CanceledError)
            # Before we raise here, we want to try to set the start operation exception (no-op if already set with a
            # handle)
            input.start_workflow_operation._set_workflow_handle(e)
            raise e
          end

          # Return handle
          Temporalio::Client::WorkflowUpdateHandle.new(
            client: @client,
            id: input.update_id,
            workflow_id: start_options.id,
            workflow_run_id: run_id,
            known_outcome: update_resp.outcome
          )
        end

        def signal_with_start_workflow(input)
          raise ArgumentError, 'Start operation is required' unless input.start_workflow_operation

          # Try to mark used before using
          input.start_workflow_operation._mark_used

          # Build req
          start_options = input.start_workflow_operation.options
          req = _start_workflow_request_from_with_start_options(
            Api::WorkflowService::V1::SignalWithStartWorkflowExecutionRequest, start_options
          )
          req.signal_name = input.signal
          req.signal_input = @client.data_converter.to_payloads(input.args)

          # Send request
          begin
            resp = @client.workflow_service.signal_with_start_workflow_execution(
              req,
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
          rescue Error::RPCError => e
            # Unpack and raise already started if that's the error, otherwise default raise
            if e.code == Error::RPCError::Code::ALREADY_EXISTS && e.grpc_status.details.first
              details = e.grpc_status.details.first.unpack(
                Api::ErrorDetails::V1::WorkflowExecutionAlreadyStartedFailure
              )
              if details
                e = Error::WorkflowAlreadyStartedError.new(
                  workflow_id: req.workflow_id,
                  workflow_type: req.workflow_type.name,
                  run_id: details.run_id
                )
              end
            end
            # Before we raise here, we want to the start operation exception
            input.start_workflow_operation._set_workflow_handle(e)
            raise e
          end

          # Set handle and return handle
          handle = Temporalio::Client::WorkflowHandle.new(
            client: @client,
            id: start_options.id,
            run_id: nil,
            result_run_id: resp.run_id,
            first_execution_run_id: resp.run_id
          )
          input.start_workflow_operation._set_workflow_handle(handle)
          handle
        end

        def _start_workflow_request_from_with_start_options(klass, start_options)
          klass.new(
            request_id: SecureRandom.uuid,
            namespace: @client.namespace,
            workflow_type: Api::Common::V1::WorkflowType.new(name: start_options.workflow),
            workflow_id: start_options.id,
            task_queue: Api::TaskQueue::V1::TaskQueue.new(name: start_options.task_queue.to_s),
            input: @client.data_converter.to_payloads(start_options.args),
            workflow_execution_timeout: ProtoUtils.seconds_to_duration(start_options.execution_timeout),
            workflow_run_timeout: ProtoUtils.seconds_to_duration(start_options.run_timeout),
            workflow_task_timeout: ProtoUtils.seconds_to_duration(start_options.task_timeout),
            identity: @client.connection.identity,
            workflow_id_reuse_policy: start_options.id_reuse_policy,
            workflow_id_conflict_policy: start_options.id_conflict_policy,
            retry_policy: start_options.retry_policy&._to_proto,
            cron_schedule: start_options.cron_schedule,
            memo: ProtoUtils.memo_to_proto(start_options.memo, @client.data_converter),
            search_attributes: start_options.search_attributes&._to_proto,
            workflow_start_delay: ProtoUtils.seconds_to_duration(start_options.start_delay),
            user_metadata: ProtoUtils.to_user_metadata(
              start_options.static_summary, start_options.static_details, @client.data_converter
            ),
            header: ProtoUtils.headers_to_proto(start_options.headers, @client.data_converter)
          )
        end

        def list_workflows(input)
          page = ListWorkflowPage.new(@client, input: input)
          return page unless input.page_size.nil?

          # If page_size is nil, automatically fetch all pages:
          Enumerator.new do |yielder|
            until page.nil?
              page.each { |execution| yielder << execution }
              page = page.next_page
            end
          end
        end

        def count_workflows(input)
          resp = @client.workflow_service.count_workflow_executions(
            Api::WorkflowService::V1::CountWorkflowExecutionsRequest.new(
              namespace: @client.namespace,
              query: input.query || ''
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          Temporalio::Client::WorkflowExecutionCount.new(
            resp.count,
            resp.groups.map do |group|
              Temporalio::Client::WorkflowExecutionCount::AggregationGroup.new(
                group.count,
                group.group_values.map { |payload| SearchAttributes._value_from_payload(payload) }
              )
            end
          )
        end

        def describe_workflow(input)
          resp = @client.workflow_service.describe_workflow_execution(
            Api::WorkflowService::V1::DescribeWorkflowExecutionRequest.new(
              namespace: @client.namespace,
              execution: Api::Common::V1::WorkflowExecution.new(
                workflow_id: input.workflow_id,
                run_id: input.run_id || ''
              )
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          Temporalio::Client::WorkflowExecution::Description.new(resp, @client.data_converter)
        end

        def fetch_workflow_history_events(input)
          Enumerator.new do |yielder|
            req = Api::WorkflowService::V1::GetWorkflowExecutionHistoryRequest.new(
              namespace: @client.namespace,
              execution: Api::Common::V1::WorkflowExecution.new(
                workflow_id: input.workflow_id,
                run_id: input.run_id || ''
              ),
              wait_new_event: input.wait_new_event,
              history_event_filter_type: input.event_filter_type,
              skip_archival: input.skip_archival
            )
            loop do
              resp = @client.workflow_service.get_workflow_execution_history(
                req,
                rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
              )
              resp.history&.events&.each { |event| yielder << event }
              break if resp.next_page_token.empty?

              req.next_page_token = resp.next_page_token
            end
          end
        end

        def signal_workflow(input)
          @client.workflow_service.signal_workflow_execution(
            Api::WorkflowService::V1::SignalWorkflowExecutionRequest.new(
              namespace: @client.namespace,
              workflow_execution: Api::Common::V1::WorkflowExecution.new(
                workflow_id: input.workflow_id,
                run_id: input.run_id || ''
              ),
              signal_name: input.signal,
              input: @client.data_converter.to_payloads(input.args),
              header: Internal::ProtoUtils.headers_to_proto(input.headers, @client.data_converter),
              identity: @client.connection.identity,
              request_id: SecureRandom.uuid
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          nil
        end

        def query_workflow(input)
          begin
            resp = @client.workflow_service.query_workflow(
              Api::WorkflowService::V1::QueryWorkflowRequest.new(
                namespace: @client.namespace,
                execution: Api::Common::V1::WorkflowExecution.new(
                  workflow_id: input.workflow_id,
                  run_id: input.run_id || ''
                ),
                query: Api::Query::V1::WorkflowQuery.new(
                  query_type: input.query,
                  query_args: @client.data_converter.to_payloads(input.args),
                  header: Internal::ProtoUtils.headers_to_proto(input.headers, @client.data_converter)
                ),
                query_reject_condition: input.reject_condition || 0
              ),
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
          rescue Error::RPCError => e
            # If the status is INVALID_ARGUMENT, we can assume it's a query failed
            # error
            raise Error::WorkflowQueryFailedError, e.message if e.code == Error::RPCError::Code::INVALID_ARGUMENT

            raise
          end
          unless resp.query_rejected.nil?
            raise Error::WorkflowQueryRejectedError.new(status: ProtoUtils.enum_to_int(
              Api::Enums::V1::WorkflowExecutionStatus, resp.query_rejected.status
            ))
          end

          results = @client.data_converter.from_payloads(resp.query_result)
          warn("Expected 0 or 1 query result, got #{results.size}") if results.size > 1
          results&.first
        end

        def start_workflow_update(input)
          if input.wait_for_stage == Temporalio::Client::WorkflowUpdateWaitStage::ADMITTED
            raise ArgumentError, 'ADMITTED wait stage not supported'
          end

          req = Api::WorkflowService::V1::UpdateWorkflowExecutionRequest.new(
            namespace: @client.namespace,
            workflow_execution: Api::Common::V1::WorkflowExecution.new(
              workflow_id: input.workflow_id,
              run_id: input.run_id || ''
            ),
            request: Api::Update::V1::Request.new(
              meta: Api::Update::V1::Meta.new(
                update_id: input.update_id,
                identity: @client.connection.identity
              ),
              input: Api::Update::V1::Input.new(
                name: input.update,
                args: @client.data_converter.to_payloads(input.args),
                header: Internal::ProtoUtils.headers_to_proto(input.headers, @client.data_converter)
              )
            ),
            wait_policy: Api::Update::V1::WaitPolicy.new(
              lifecycle_stage: input.wait_for_stage
            )
          )

          # Repeatedly try to invoke start until the update reaches user-provided
          # wait stage or is at least ACCEPTED (as of the time of this writing,
          # the user cannot specify sooner than ACCEPTED)
          # @type var resp: untyped
          resp = nil
          expected_stage = ProtoUtils.enum_to_int(Api::Enums::V1::UpdateWorkflowExecutionLifecycleStage,
                                                  req.wait_policy.lifecycle_stage)
          accepted_stage = ProtoUtils.enum_to_int(Api::Enums::V1::UpdateWorkflowExecutionLifecycleStage,
                                                  Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED)
          loop do
            resp = @client.workflow_service.update_workflow_execution(
              req,
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )

            # We're only done if the response stage is after the requested stage
            # or the response stage is accepted
            actual_stage = ProtoUtils.enum_to_int(Api::Enums::V1::UpdateWorkflowExecutionLifecycleStage, resp.stage)
            break if actual_stage >= expected_stage || actual_stage >= accepted_stage
          rescue Error::RPCError => e
            # Deadline exceeded or cancel is a special error type
            if e.code == Error::RPCError::Code::DEADLINE_EXCEEDED || e.code == Error::RPCError::Code::CANCELED
              raise Error::WorkflowUpdateRPCTimeoutOrCanceledError
            end

            raise
          rescue Error::CanceledError
            raise Error::WorkflowUpdateRPCTimeoutOrCanceledError
          end

          # If the user wants to wait until completed, we must poll until outcome
          # if not already there
          if input.wait_for_stage == Temporalio::Client::WorkflowUpdateWaitStage::COMPLETED && !resp.outcome
            resp.outcome = @client._impl.poll_workflow_update(
              Temporalio::Client::Interceptor::PollWorkflowUpdateInput.new(
                workflow_id: input.workflow_id,
                run_id: input.run_id,
                update_id: input.update_id,
                rpc_options: input.rpc_options
              )
            )
          end

          Temporalio::Client::WorkflowUpdateHandle.new(
            client: @client,
            id: input.update_id,
            workflow_id: input.workflow_id,
            workflow_run_id: input.run_id,
            known_outcome: resp.outcome
          )
        end

        def poll_workflow_update(input)
          req = Api::WorkflowService::V1::PollWorkflowExecutionUpdateRequest.new(
            namespace: @client.namespace,
            update_ref: Api::Update::V1::UpdateRef.new(
              workflow_execution: Api::Common::V1::WorkflowExecution.new(
                workflow_id: input.workflow_id,
                run_id: input.run_id || ''
              ),
              update_id: input.update_id
            ),
            identity: @client.connection.identity,
            wait_policy: Api::Update::V1::WaitPolicy.new(
              lifecycle_stage: Temporalio::Client::WorkflowUpdateWaitStage::COMPLETED
            )
          )

          # Continue polling as long as we have no outcome
          loop do
            resp = @client.workflow_service.poll_workflow_execution_update(
              req,
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
            return resp.outcome if resp.outcome
          rescue Error::RPCError => e
            # Deadline exceeded or cancel is a special error type
            if e.code == Error::RPCError::Code::DEADLINE_EXCEEDED || e.code == Error::RPCError::Code::CANCELED
              raise Error::WorkflowUpdateRPCTimeoutOrCanceledError
            end

            raise
          end
        end

        def cancel_workflow(input)
          @client.workflow_service.request_cancel_workflow_execution(
            Api::WorkflowService::V1::RequestCancelWorkflowExecutionRequest.new(
              namespace: @client.namespace,
              workflow_execution: Api::Common::V1::WorkflowExecution.new(
                workflow_id: input.workflow_id,
                run_id: input.run_id || ''
              ),
              first_execution_run_id: input.first_execution_run_id,
              identity: @client.connection.identity,
              request_id: SecureRandom.uuid
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          nil
        end

        def terminate_workflow(input)
          @client.workflow_service.terminate_workflow_execution(
            Api::WorkflowService::V1::TerminateWorkflowExecutionRequest.new(
              namespace: @client.namespace,
              workflow_execution: Api::Common::V1::WorkflowExecution.new(
                workflow_id: input.workflow_id,
                run_id: input.run_id || ''
              ),
              reason: input.reason || '',
              first_execution_run_id: input.first_execution_run_id,
              details: @client.data_converter.to_payloads(input.details),
              identity: @client.connection.identity
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          nil
        end

        def create_schedule(input)
          if input.schedule.state.limited_actions && input.schedule.state.remaining_actions.zero?
            raise 'Must set limited actions to false if there are no remaining actions set'
          end
          if !input.schedule.state.limited_actions && !input.schedule.state.remaining_actions.zero?
            raise 'Must set limited actions to true if there are remaining actions set'
          end

          @client.workflow_service.create_schedule(
            Api::WorkflowService::V1::CreateScheduleRequest.new(
              namespace: @client.namespace,
              schedule_id: input.id,
              schedule: input.schedule._to_proto(@client.data_converter),
              initial_patch: if input.trigger_immediately || !input.backfills.empty?
                               Api::Schedule::V1::SchedulePatch.new(
                                 trigger_immediately: if input.trigger_immediately
                                                        Api::Schedule::V1::TriggerImmediatelyRequest.new(
                                                          overlap_policy: input.schedule.policy.overlap
                                                        )
                                                      end,
                                 backfill_request: input.backfills.map(&:_to_proto)
                               )
                             end,
              identity: @client.connection.identity,
              request_id: SecureRandom.uuid,
              memo: ProtoUtils.memo_to_proto(input.memo, @client.data_converter),
              search_attributes: input.search_attributes&._to_proto
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          Temporalio::Client::ScheduleHandle.new(client: @client, id: input.id)
        rescue Error::RPCError => e
          # Unpack and raise already started if that's the error, otherwise default raise
          details = if e.code == Error::RPCError::Code::ALREADY_EXISTS && e.grpc_status.details.first
                      e.grpc_status.details.first.unpack(Api::ErrorDetails::V1::WorkflowExecutionAlreadyStartedFailure)
                    end
          raise Error::ScheduleAlreadyRunningError if details

          raise
        end

        def list_schedules(input)
          Enumerator.new do |yielder|
            req = Api::WorkflowService::V1::ListSchedulesRequest.new(
              namespace: @client.namespace,
              query: input.query || ''
            )
            loop do
              resp = @client.workflow_service.list_schedules(
                req,
                rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
              )
              resp.schedules.each do |raw_entry|
                yielder << Temporalio::Client::Schedule::List::Description.new(
                  raw_entry:,
                  data_converter: @client.data_converter
                )
              end
              break if resp.next_page_token.empty?

              req.next_page_token = resp.next_page_token
            end
          end
        end

        def backfill_schedule(input)
          @client.workflow_service.patch_schedule(
            Api::WorkflowService::V1::PatchScheduleRequest.new(
              namespace: @client.namespace,
              schedule_id: input.id,
              patch: Api::Schedule::V1::SchedulePatch.new(
                backfill_request: input.backfills.map(&:_to_proto)
              ),
              identity: @client.connection.identity,
              request_id: SecureRandom.uuid
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          nil
        end

        def delete_schedule(input)
          @client.workflow_service.delete_schedule(
            Api::WorkflowService::V1::DeleteScheduleRequest.new(
              namespace: @client.namespace,
              schedule_id: input.id,
              identity: @client.connection.identity
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          nil
        end

        def describe_schedule(input)
          Temporalio::Client::Schedule::Description.new(
            id: input.id,
            raw_description: @client.workflow_service.describe_schedule(
              Api::WorkflowService::V1::DescribeScheduleRequest.new(
                namespace: @client.namespace,
                schedule_id: input.id
              ),
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            ),
            data_converter: @client.data_converter
          )
        end

        def pause_schedule(input)
          @client.workflow_service.patch_schedule(
            Api::WorkflowService::V1::PatchScheduleRequest.new(
              namespace: @client.namespace,
              schedule_id: input.id,
              patch: Api::Schedule::V1::SchedulePatch.new(pause: input.note),
              identity: @client.connection.identity,
              request_id: SecureRandom.uuid
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          nil
        end

        def trigger_schedule(input)
          @client.workflow_service.patch_schedule(
            Api::WorkflowService::V1::PatchScheduleRequest.new(
              namespace: @client.namespace,
              schedule_id: input.id,
              patch: Api::Schedule::V1::SchedulePatch.new(
                trigger_immediately: Api::Schedule::V1::TriggerImmediatelyRequest.new(
                  overlap_policy: input.overlap || 0
                )
              ),
              identity: @client.connection.identity,
              request_id: SecureRandom.uuid
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          nil
        end

        def unpause_schedule(input)
          @client.workflow_service.patch_schedule(
            Api::WorkflowService::V1::PatchScheduleRequest.new(
              namespace: @client.namespace,
              schedule_id: input.id,
              patch: Api::Schedule::V1::SchedulePatch.new(unpause: input.note),
              identity: @client.connection.identity,
              request_id: SecureRandom.uuid
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          nil
        end

        def update_schedule(input)
          # TODO(cretz): This is supposed to be a retry-conflict loop, but we do
          # not yet have a way to know update failure is due to conflict token
          # mismatch
          update = input.updater.call(
            Temporalio::Client::Schedule::Update::Input.new(
              description: Temporalio::Client::Schedule::Description.new(
                id: input.id,
                raw_description: @client.workflow_service.describe_schedule(
                  Api::WorkflowService::V1::DescribeScheduleRequest.new(
                    namespace: @client.namespace,
                    schedule_id: input.id
                  ),
                  rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
                ),
                data_converter: @client.data_converter
              )
            )
          )
          # Do nothing if update is nil, fail if not an expected update
          return nil if update.nil?

          unless update.is_a?(Temporalio::Client::Schedule::Update)
            raise TypeError,
                  'Expected result of update block to be a Schedule::Update'
          end

          @client.workflow_service.update_schedule(
            Api::WorkflowService::V1::UpdateScheduleRequest.new(
              namespace: @client.namespace,
              schedule_id: input.id,
              schedule: update.schedule._to_proto(@client.data_converter),
              search_attributes: update.search_attributes&._to_proto,
              identity: @client.connection.identity,
              request_id: SecureRandom.uuid
            ),
            rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
          )
          nil
        end

        def heartbeat_async_activity(input)
          resp = if input.task_token_or_id_reference.is_a?(Temporalio::Client::ActivityIDReference)
                   @client.workflow_service.record_activity_task_heartbeat_by_id(
                     Api::WorkflowService::V1::RecordActivityTaskHeartbeatByIdRequest.new(
                       workflow_id: input.task_token_or_id_reference.workflow_id,
                       run_id: input.task_token_or_id_reference.run_id,
                       activity_id: input.task_token_or_id_reference.activity_id,
                       namespace: @client.namespace,
                       identity: @client.connection.identity,
                       details: @client.data_converter.to_payloads(input.details)
                     ),
                     rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
                   )
                 else
                   @client.workflow_service.record_activity_task_heartbeat(
                     Api::WorkflowService::V1::RecordActivityTaskHeartbeatRequest.new(
                       task_token: input.task_token_or_id_reference,
                       namespace: @client.namespace,
                       identity: @client.connection.identity,
                       details: @client.data_converter.to_payloads(input.details)
                     ),
                     rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
                   )
                 end
          raise Error::AsyncActivityCanceledError if resp.cancel_requested

          nil
        end

        def complete_async_activity(input)
          if input.task_token_or_id_reference.is_a?(Temporalio::Client::ActivityIDReference)
            @client.workflow_service.respond_activity_task_completed_by_id(
              Api::WorkflowService::V1::RespondActivityTaskCompletedByIdRequest.new(
                workflow_id: input.task_token_or_id_reference.workflow_id,
                run_id: input.task_token_or_id_reference.run_id,
                activity_id: input.task_token_or_id_reference.activity_id,
                namespace: @client.namespace,
                identity: @client.connection.identity,
                result: @client.data_converter.to_payloads([input.result])
              ),
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
          else
            @client.workflow_service.respond_activity_task_completed(
              Api::WorkflowService::V1::RespondActivityTaskCompletedRequest.new(
                task_token: input.task_token_or_id_reference,
                namespace: @client.namespace,
                identity: @client.connection.identity,
                result: @client.data_converter.to_payloads([input.result])
              ),
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
          end
          nil
        end

        def fail_async_activity(input)
          if input.task_token_or_id_reference.is_a?(Temporalio::Client::ActivityIDReference)
            @client.workflow_service.respond_activity_task_failed_by_id(
              Api::WorkflowService::V1::RespondActivityTaskFailedByIdRequest.new(
                workflow_id: input.task_token_or_id_reference.workflow_id,
                run_id: input.task_token_or_id_reference.run_id,
                activity_id: input.task_token_or_id_reference.activity_id,
                namespace: @client.namespace,
                identity: @client.connection.identity,
                failure: @client.data_converter.to_failure(input.error),
                last_heartbeat_details: if input.last_heartbeat_details.empty?
                                          nil
                                        else
                                          @client.data_converter.to_payloads(input.last_heartbeat_details)
                                        end
              ),
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
          else
            @client.workflow_service.respond_activity_task_failed(
              Api::WorkflowService::V1::RespondActivityTaskFailedRequest.new(
                task_token: input.task_token_or_id_reference,
                namespace: @client.namespace,
                identity: @client.connection.identity,
                failure: @client.data_converter.to_failure(input.error),
                last_heartbeat_details: if input.last_heartbeat_details.empty?
                                          nil
                                        else
                                          @client.data_converter.to_payloads(input.last_heartbeat_details)
                                        end
              ),
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
          end
          nil
        end

        def report_cancellation_async_activity(input)
          if input.task_token_or_id_reference.is_a?(Temporalio::Client::ActivityIDReference)
            @client.workflow_service.respond_activity_task_canceled_by_id(
              Api::WorkflowService::V1::RespondActivityTaskCanceledByIdRequest.new(
                workflow_id: input.task_token_or_id_reference.workflow_id,
                run_id: input.task_token_or_id_reference.run_id,
                activity_id: input.task_token_or_id_reference.activity_id,
                namespace: @client.namespace,
                identity: @client.connection.identity,
                details: @client.data_converter.to_payloads(input.details)
              ),
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
          else
            @client.workflow_service.respond_activity_task_canceled(
              Api::WorkflowService::V1::RespondActivityTaskCanceledRequest.new(
                task_token: input.task_token_or_id_reference,
                namespace: @client.namespace,
                identity: @client.connection.identity,
                details: @client.data_converter.to_payloads(input.details)
              ),
              rpc_options: Implementation.with_default_rpc_options(input.rpc_options)
            )
          end
          nil
        end
      end
    end
  end
end
