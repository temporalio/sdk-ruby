# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/error'

module Temporalio
  class Error
    # Base class for all Temporal serializable failures.
    class Failure < Error
    end

    # Error raised by a client or workflow when a workflow execution has already started.
    class WorkflowAlreadyStartedError < Failure
      # @return [String] ID of the already-started workflow.
      attr_reader :workflow_id

      # @return [String] Workflow type name of the already-started workflow.
      attr_reader :workflow_type

      # @return [String, nil] Run ID of the already-started workflow if this was raised by the client.
      attr_reader :run_id

      # @!visibility private
      def initialize(workflow_id:, workflow_type:, run_id:)
        super('Workflow execution already started')
        @workflow_id = workflow_id
        @workflow_type = workflow_type
        @run_id = run_id
      end
    end

    # Error raised during workflow/activity execution.
    class ApplicationError < Failure
      # @return [Array<Object, nil>] User-defined details on the error.
      attr_reader :details

      # @return [String, nil] General error type.
      attr_reader :type

      # @return [Boolean] Whether the error was set as non-retryable when created.
      #
      # @note This is not whether the error is non-retryable via other means such as retry policy. This is just
      # whether the error was marked non-retryable upon creation by the user.
      attr_reader :non_retryable

      # @return [Float, nil] Delay in seconds before the next activity retry attempt.
      attr_reader :next_retry_delay

      # @return [Category] Error category.
      attr_reader :category

      # Create an application error.
      #
      # @param message [String] Error message.
      # @param details [Array<Object, nil>] Error details.
      # @param type [String, nil] Error type.
      # @param non_retryable [Boolean] Whether this error should be considered non-retryable.
      # @param next_retry_delay [Float, nil] Specific amount of time to delay before next retry.
      # @param category [Category] Error category.
      def initialize(
        message,
        *details,
        type: nil,
        non_retryable: false,
        next_retry_delay: nil,
        category: Category::UNSPECIFIED
      )
        super(message)
        @details = details
        @type = type
        @non_retryable = non_retryable
        @next_retry_delay = next_retry_delay
        @category = category
      end

      # @return [Boolean] Inverse of {non_retryable}.
      def retryable?
        !@non_retryable
      end

      # Error category.
      module Category
        UNSPECIFIED = Api::Enums::V1::ApplicationErrorCategory::APPLICATION_ERROR_CATEGORY_UNSPECIFIED
        BENIGN = Api::Enums::V1::ApplicationErrorCategory::APPLICATION_ERROR_CATEGORY_BENIGN
      end
    end

    # Error raised on workflow/activity cancellation.
    class CanceledError < Failure
      attr_reader :details

      # @!visibility private
      def initialize(message, details: [])
        super(message)
        @details = details
      end
    end

    # Error raised on workflow termination.
    class TerminatedError < Failure
      # @return [Array<Object?>] User-defined details on the error.
      attr_reader :details

      # @!visibility private
      def initialize(message, details:)
        super(message)
        @details = details
      end
    end

    # Error raised on workflow/activity timeout.
    class TimeoutError < Failure
      # @return [TimeoutType] Type of timeout error.
      attr_reader :type

      # @return [Array<Object>] Last heartbeat details if this is for an activity heartbeat.
      attr_reader :last_heartbeat_details

      # @!visibility private
      def initialize(message, type:, last_heartbeat_details:)
        super(message)
        @type = type
        @last_heartbeat_details = last_heartbeat_details
      end

      # Type of timeout error.
      module TimeoutType
        START_TO_CLOSE = Api::Enums::V1::TimeoutType::TIMEOUT_TYPE_START_TO_CLOSE
        SCHEDULE_TO_START = Api::Enums::V1::TimeoutType::TIMEOUT_TYPE_SCHEDULE_TO_START
        SCHEDULE_TO_CLOSE = Api::Enums::V1::TimeoutType::TIMEOUT_TYPE_SCHEDULE_TO_CLOSE
        HEARTBEAT = Api::Enums::V1::TimeoutType::TIMEOUT_TYPE_HEARTBEAT
      end
    end

    # Error originating in the Temporal server.
    class ServerError < Failure
      # @return [Boolean] Whether this error is non-retryable.
      attr_reader :non_retryable

      # @!visibility private
      def initialize(message, non_retryable:)
        super(message)
        @non_retryable = non_retryable
      end

      # @return [Boolean] Inverse of {non_retryable}.
      def retryable?
        !@non_retryable
      end
    end

    # Current retry state of the workflow/activity during error.
    module RetryState
      IN_PROGRESS = Api::Enums::V1::RetryState::RETRY_STATE_IN_PROGRESS
      NON_RETRYABLE_FAILURE = Api::Enums::V1::RetryState::RETRY_STATE_NON_RETRYABLE_FAILURE
      TIMEOUT = Api::Enums::V1::RetryState::RETRY_STATE_TIMEOUT
      MAXIMUM_ATTEMPTS_REACHED = Api::Enums::V1::RetryState::RETRY_STATE_MAXIMUM_ATTEMPTS_REACHED
      RETRY_POLICY_NOT_SET = Api::Enums::V1::RetryState::RETRY_STATE_RETRY_POLICY_NOT_SET
      INTERNAL_SERVER_ERROR = Api::Enums::V1::RetryState::RETRY_STATE_INTERNAL_SERVER_ERROR
      CANCEL_REQUESTED = Api::Enums::V1::RetryState::RETRY_STATE_CANCEL_REQUESTED
    end

    # Error raised on activity failure.
    class ActivityError < Failure
      # @return [Integer] Scheduled event ID for this activity.
      attr_reader :scheduled_event_id
      # @return [Integer] Started event ID for this activity.
      attr_reader :started_event_id
      # @return [String] Client/worker identity.
      attr_reader :identity
      # @return [String] Activity type name.
      attr_reader :activity_type
      # @return [String] Activity ID.
      attr_reader :activity_id
      # @return [RetryState, nil] Retry state.
      attr_reader :retry_state

      # @!visibility private
      def initialize(
        message,
        scheduled_event_id:,
        started_event_id:,
        identity:,
        activity_type:,
        activity_id:,
        retry_state:
      )
        super(message)
        @scheduled_event_id = scheduled_event_id
        @started_event_id = started_event_id
        @identity = identity
        @activity_type = activity_type
        @activity_id = activity_id
        @retry_state = retry_state
      end
    end

    # Error raised on child workflow failure.
    class ChildWorkflowError < Failure
      # @return [String] Child workflow namespace.
      attr_reader :namespace
      # @return [String] Child workflow ID.
      attr_reader :workflow_id
      # @return [String] Child workflow run ID.
      attr_reader :run_id
      # @return [String] Child workflow type name.
      attr_reader :workflow_type
      # @return [Integer] Child workflow initiated event ID.
      attr_reader :initiated_event_id
      # @return [Integer] Child workflow started event ID.
      attr_reader :started_event_id
      # @return [RetryState, nil] Retry state.
      attr_reader :retry_state

      # @!visibility private
      def initialize(
        message,
        namespace:,
        workflow_id:,
        run_id:,
        workflow_type:,
        initiated_event_id:,
        started_event_id:,
        retry_state:
      )
        super(message)
        @namespace = namespace
        @workflow_id = workflow_id
        @run_id = run_id
        @workflow_type = workflow_type
        @initiated_event_id = initiated_event_id
        @started_event_id = started_event_id
        @retry_state = retry_state
      end
    end

    # Error raised on Nexus operation failure.
    #
    # WARNING: Nexus support is experimental.
    class NexusOperationError < Failure
      # @return [String] Nexus endpoint.
      attr_reader :endpoint
      # @return [String] Nexus service.
      attr_reader :service
      # @return [String] Nexus operation.
      attr_reader :operation
      # @return [String, nil] Operation token for async operations.
      attr_reader :operation_token

      # @!visibility private
      def initialize(
        message,
        endpoint:,
        service:,
        operation:,
        operation_token:
      )
        super(message)
        @endpoint = endpoint
        @service = service
        @operation = operation
        @operation_token = operation_token
      end
    end

    # Error raised from a Nexus handler.
    #
    # WARNING: Nexus support is experimental.
    class NexusHandlerError < Failure
      # @return [Symbol] Error type from the handler.
      attr_reader :error_type

      # @return [RetryBehavior] Retry behavior for the error.
      attr_reader :retry_behavior

      # @!visibility private
      def initialize(
        message,
        error_type:,
        retry_behavior:
      )
        super(message)
        @error_type = error_type.to_sym
        @retry_behavior = retry_behavior
      end

      # Nexus handler error retry behavior.
      module RetryBehavior
        # Unspecified retry behavior.
        UNSPECIFIED =
          Api::Enums::V1::NexusHandlerErrorRetryBehavior::NEXUS_HANDLER_ERROR_RETRY_BEHAVIOR_UNSPECIFIED

        # Retryable error.
        RETRYABLE =
          Api::Enums::V1::NexusHandlerErrorRetryBehavior::NEXUS_HANDLER_ERROR_RETRY_BEHAVIOR_RETRYABLE

        # Non-retryable error.
        NON_RETRYABLE =
          Api::Enums::V1::NexusHandlerErrorRetryBehavior::NEXUS_HANDLER_ERROR_RETRY_BEHAVIOR_NON_RETRYABLE
      end
    end
  end
end
