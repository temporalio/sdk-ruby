# TODO: Figure out the hierarchy
require 'temporalio/errors'

module Temporalio
  class Error
    # Base for runtime failures during workflow/activity execution.
    class Failure < Error
      # @return [Temporalio::Api::Failure::V1::Failure, nil] Original proto failure
      attr_reader :raw

      def initialize(message, raw: nil, cause: nil)
        super(message)

        @raw = raw
        @cause = cause
      end

      def cause
        @cause || super
      end
    end

    # Error raised during workflow/activity execution.
    class ApplicationError < Failure
      # @return [String] General error type.
      attr_reader :type

      # @return [Array<any>] User-defined details on the error.
      attr_reader :details

      # @return [Bool] Whether the error is non-retryable.
      attr_reader :non_retryable

      def initialize(message, type:, details: [], non_retryable: false, raw: nil, cause: nil)
        super(message, raw: raw, cause: cause)

        @type = type
        @details = details
        @non_retryable = non_retryable
      end

      def retryable?
        !non_retryable
      end
    end

    # Error raised on workflow/activity timeout.
    class TimeoutError < Failure
      # @return [Symbol] Type of timeout error. Refer to {Temporalio::TimeoutType}.
      attr_reader :type

      # @return [Array<any>] Last heartbeat details if this is for an activity heartbeat.
      attr_reader :last_heartbeat_details

      def initialize(message, type:, last_heartbeat_details: [], raw: nil, cause: nil)
        super(message, raw: raw, cause: cause)

        @type = type
        @last_heartbeat_details = last_heartbeat_details
      end
    end

    # Error raised on workflow/activity cancellation.
    class CancelledError < Failure
      # @return [Array<any>] User-defined details on the error.
      attr_reader :details

      def initialize(message, details: [], raw: nil, cause: nil)
        super(message, raw: raw, cause: cause)

        @details = details
      end
    end

    # Error raised on workflow cancellation.
    class TerminatedError < Failure; end

    # Error originating in the Temporal server.
    class ServerError < Failure
      # @return [Bool] Whether the error is non-retryable.
      attr_reader :non_retryable

      def initialize(message, non_retryable:, raw: nil, cause: nil)
        super(message, raw: raw, cause: cause)

        @non_retryable = non_retryable
      end

      def retryable?
        !non_retryable
      end
    end

    class ResetWorkflowError < Failure
      # @return [Array<any>] Last heartbeat details if this is for an activity heartbeat.
      attr_reader :last_heartbeat_details

      def initialize(message, last_heartbeat_details: [], raw: nil, cause: nil)
        super(message, raw: raw, cause: cause)

        @last_heartbeat_details = last_heartbeat_details
      end
    end

    # Error raised on activity failure.
    class ActivityError < Failure
      # @return [Integer] Scheduled event ID for this error.
      attr_reader :scheduled_event_id

      # @return [Integer] Started event ID for this error.
      attr_reader :started_event_id

      # @return [String] Identity for this error.
      attr_reader :identity

      # @return [String] Activity name for this error.
      attr_reader :activity_name

      # @return [String] Activity ID for this error.
      attr_reader :activity_id

      # @return [Symbol] Retry state for this error. Refer to {Temporalio::RetryState}.
      attr_reader :retry_state

      def initialize(
        message,
        scheduled_event_id:,
        started_event_id:,
        identity:,
        activity_name:,
        activity_id:,
        retry_state:,
        raw: nil,
        cause: nil
      )
        super(message, raw: raw, cause: cause)

        @scheduled_event_id = scheduled_event_id
        @started_event_id = started_event_id
        @identity = identity
        @activity_name = activity_name
        @activity_id = activity_id
        @retry_state = retry_state
      end
    end

    # Error raised on child workflow failure.
    class ChildWorkflowError < Failure
      # @return [String] Namespace for this error.
      attr_reader :namespace

      # @return [String] Workflow ID for this error.
      attr_reader :workflow_id

      # @return [String] Run ID for this error.
      attr_reader :run_id

      # @return [String] Workflow name for this error.
      attr_reader :workflow_name

      # @return [Integer] Initiated event ID for this error.
      attr_reader :initiated_event_id

      # @return [Integer] Started event ID for this error.
      attr_reader :started_event_id

      # @return [Symbol] Retry state for this error. Refer to {Temporalio::RetryState}.
      attr_reader :retry_state

      def initialize(
        message,
        namespace:,
        workflow_id:,
        run_id:,
        workflow_name:,
        initiated_event_id:,
        started_event_id:,
        retry_state:,
        raw: nil,
        cause: nil
      )
        super(message, raw: raw, cause: cause)

        @namespace = namespace
        @workflow_id = workflow_id
        @run_id = run_id
        @workflow_name = workflow_name
        @initiated_event_id = initiated_event_id
        @started_event_id = started_event_id
        @retry_state = retry_state
      end
    end
  end
end
