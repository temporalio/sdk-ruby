# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/activity_execution_status'
require 'temporalio/client/pending_activity_state'
require 'temporalio/internal/proto_utils'
require 'temporalio/priority'
require 'temporalio/retry_policy'
require 'temporalio/search_attributes'
require 'temporalio/worker_deployment_version'

module Temporalio
  class Client
    # Info for a standalone activity execution. Returned by list_activities; extended by {Description}
    # for describe results.
    #
    # WARNING: Standalone Activities are experimental.
    class ActivityExecution
      # @return [Api::Activity::V1::ActivityExecutionListInfo, Api::Activity::V1::ActivityExecutionInfo]
      #   Underlying protobuf info.
      attr_reader :raw_info

      # @!visibility private
      def initialize(raw_info)
        @raw_info = raw_info
        @search_attributes = Internal::ProtoUtils::LazySearchAttributes.new(raw_info.search_attributes)
      end

      # @return [String] ID for the activity.
      def activity_id
        @raw_info.activity_id
      end

      # @return [String] Run ID for this activity execution attempt.
      def activity_run_id
        Internal::ProtoUtils.string_or(@raw_info.run_id, nil)
      end

      # @return [String] Type name of the activity.
      def activity_type
        @raw_info.activity_type&.name
      end

      # @return [Time, nil] When the activity was scheduled.
      def schedule_time
        Internal::ProtoUtils.timestamp_to_time(@raw_info.schedule_time)
      end

      # @return [Time, nil] When the first activity task was made available for dispatch. Equals
      #   schedule_time + start_delay; equal to schedule_time when no start delay is set.
      def execution_time
        Internal::ProtoUtils.timestamp_to_time(@raw_info.execution_time)
      end

      # @return [Time, nil] When the activity reached a terminal state.
      def close_time
        Internal::ProtoUtils.timestamp_to_time(@raw_info.close_time)
      end

      # @return [ActivityExecutionStatus] Overall status for the activity.
      def status
        Internal::ProtoUtils.enum_to_int(Api::Enums::V1::ActivityExecutionStatus, @raw_info.status)
      end

      # @return [SearchAttributes, nil] Search attributes attached to this activity if any.
      def search_attributes
        @search_attributes.get
      end

      # @return [String] Task queue for the activity.
      def task_queue
        @raw_info.task_queue
      end

      # @return [Float, nil] How long this activity has been running across all attempts, in seconds.
      def execution_duration
        Internal::ProtoUtils.duration_to_seconds(@raw_info.execution_duration)
      end

      # Rich description of a standalone activity execution; returned by {ActivityHandle#describe}.
      #
      # WARNING: Standalone Activities are experimental.
      class Description < ActivityExecution
        # @return [Api::WorkflowService::V1::DescribeActivityExecutionResponse] Underlying protobuf response.
        attr_reader :raw_description

        # @!visibility private
        def initialize(raw_description, data_converter)
          super(raw_description.info)
          @raw_description = raw_description
          @data_converter = data_converter
        end

        # @return [PendingActivityState, nil] More detailed breakdown of the running state when
        #   the activity's status is RUNNING; nil otherwise.
        def run_state
          Internal::ProtoUtils.enum_to_int(Api::Enums::V1::PendingActivityState, @raw_info.run_state,
                                           zero_means_nil: true)
        end

        # @return [Float, nil] Schedule-to-close timeout in seconds.
        def schedule_to_close_timeout
          Internal::ProtoUtils.duration_to_seconds(@raw_info.schedule_to_close_timeout)
        end

        # @return [Float, nil] Schedule-to-start timeout in seconds.
        def schedule_to_start_timeout
          Internal::ProtoUtils.duration_to_seconds(@raw_info.schedule_to_start_timeout)
        end

        # @return [Float, nil] Start-to-close timeout in seconds.
        def start_to_close_timeout
          Internal::ProtoUtils.duration_to_seconds(@raw_info.start_to_close_timeout)
        end

        # @return [Float, nil] Heartbeat timeout in seconds.
        def heartbeat_timeout
          Internal::ProtoUtils.duration_to_seconds(@raw_info.heartbeat_timeout)
        end

        # @return [Float, nil] Delay in seconds before the first activity task is made available for
        #   dispatch. Not applied to retry attempts.
        def start_delay
          Internal::ProtoUtils.duration_to_seconds(@raw_info.start_delay)
        end

        # Whether heartbeat details are present on this description. False when the activity
        # recorded none, and also when {ActivityHandle#describe} was called without
        # `include_heartbeat_details:`.
        #
        # @return [Boolean] Whether heartbeat details are present.
        def has_heartbeat_details? # rubocop:disable Naming/PredicatePrefix
          !@raw_info.heartbeat_details&.payloads.nil? && !@raw_info.heartbeat_details.payloads.empty?
        end

        # Deserialized last-heartbeat details. Empty when no heartbeat has been recorded.
        #
        # @param hints [Array<Object>, nil] Hints, if any, to assist conversion.
        # @return [Array<Object>] Converted details.
        def heartbeat_details(hints: nil)
          @data_converter.from_payloads(@raw_info.heartbeat_details, hints:)
        end

        # Whether the activity's input is present. False unless {ActivityHandle#describe} was
        # called with `include_input:`.
        #
        # @return [Boolean] Whether input is present.
        def has_input? # rubocop:disable Naming/PredicatePrefix
          !@raw_description.input.nil?
        end

        # Deserialized activity input, one element per argument. Empty when no input is present.
        #
        # @param hints [Array<Object>, nil] Hints, if any, to assist conversion.
        # @return [Array<Object>] Converted arguments.
        def input(hints: nil)
          @data_converter.from_payloads(@raw_description.input, hints:)
        end

        # Whether the activity closed with a successful result. False while the activity is still
        # running, when it closed with a failure, and when {ActivityHandle#describe} was called
        # without `include_outcome:`.
        #
        # @return [Boolean] Whether a result is present.
        def has_result? # rubocop:disable Naming/PredicatePrefix
          @raw_description.outcome&.value == :result
        end

        # Deserialized result the activity closed with. Nil when no result is present (still
        # running, closed with a failure, or `include_outcome:` was not requested).
        #
        # @param hint [Object, nil] Hint, if any, to assist conversion.
        # @return [Object, nil] Converted result.
        def result(hint: nil)
          return nil unless has_result?

          @data_converter.from_payloads(@raw_description.outcome.result, hints: Array(hint)).first
        end

        # Failure the activity closed with. Nil when the activity did not close with a failure or
        # when {ActivityHandle#describe} was called without `include_outcome:`.
        #
        # This is the terminal outcome; {#last_failure} is the failure of the most recent attempt,
        # which may be set while the activity is still retrying.
        #
        # @return [Error::Failure, nil] Converted failure.
        def failure
          return nil unless @raw_description.outcome&.value == :failure

          @data_converter.from_failure(@raw_description.outcome.failure)
        end

        # @return [RetryPolicy] Retry policy in effect for this activity.
        def retry_policy
          RetryPolicy._from_proto(@raw_info.retry_policy)
        end

        # @return [Time, nil] Time the last heartbeat was recorded.
        def last_heartbeat_time
          Internal::ProtoUtils.timestamp_to_time(@raw_info.last_heartbeat_time)
        end

        # @return [Time, nil] Time the last attempt started.
        def last_started_time
          Internal::ProtoUtils.timestamp_to_time(@raw_info.last_started_time)
        end

        # @return [Integer] Current attempt number. Attempts start at 1 and increment on each retry.
        def attempt
          @raw_info.attempt
        end

        # Whether a last failure is present on this description. False when the activity has no
        # failed attempt, and also when {ActivityHandle#describe} was called without
        # `include_last_failure:`.
        #
        # @return [Boolean] Whether a last failure is present.
        def has_last_failure? # rubocop:disable Naming/PredicatePrefix
          !@raw_info.last_failure.nil?
        end

        # @return [Error::Failure, nil] Failure of the last failed attempt if any.
        def last_failure
          return nil unless @raw_info.last_failure

          @data_converter.from_failure(@raw_info.last_failure)
        end

        # @return [Time, nil] Schedule time + schedule-to-close timeout.
        def expiration_time
          Internal::ProtoUtils.timestamp_to_time(@raw_info.expiration_time)
        end

        # @return [String, nil] Identity of the worker that last picked up this activity.
        def last_worker_identity
          Internal::ProtoUtils.string_or(@raw_info.last_worker_identity, nil)
        end

        # @return [Float, nil] Time from last attempt failure to next retry, in seconds.
        def current_retry_interval
          Internal::ProtoUtils.duration_to_seconds(@raw_info.current_retry_interval)
        end

        # @return [Time, nil] Time when the last attempt completed.
        def last_attempt_complete_time
          Internal::ProtoUtils.timestamp_to_time(@raw_info.last_attempt_complete_time)
        end

        # @return [Time, nil] Time when the next attempt will be scheduled.
        def next_attempt_schedule_time
          Internal::ProtoUtils.timestamp_to_time(@raw_info.next_attempt_schedule_time)
        end

        # @return [WorkerDeploymentVersion, nil] Worker deployment version this activity was last dispatched to.
        def last_deployment_version
          raw = @raw_info.last_deployment_version
          return nil unless raw

          WorkerDeploymentVersion.new(
            deployment_name: raw.deployment_name,
            build_id: raw.build_id
          )
        end

        # @return [Priority] Priority of this activity.
        def priority
          Priority._from_proto(@raw_info.priority)
        end

        # @return [String, nil] Reason given when cancellation was requested.
        def canceled_reason
          Internal::ProtoUtils.string_or(@raw_info.canceled_reason, nil)
        end

        # @return [String, nil] Static user-metadata summary on the activity.
        def static_summary
          user_metadata.first
        end

        # @return [String, nil] Static user-metadata details on the activity. May be in markdown format.
        def static_details
          user_metadata.last
        end

        private

        def user_metadata
          @user_metadata ||= Internal::ProtoUtils.from_user_metadata(
            @raw_info.user_metadata, @data_converter
          )
        end
      end
    end
  end
end
