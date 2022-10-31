# TODO: Figure out the hierarchy
require 'temporal/errors'

module Temporal
  class Error
    class Failure < Error
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

    class ApplicationError < Failure
      attr_reader :type, :details, :non_retryable

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

    class TimeoutError < Failure
      attr_reader :type, :last_heartbeat_details

      def initialize(message, type:, last_heartbeat_details: [], raw: nil, cause: nil)
        super(message, raw: raw, cause: cause)

        @type = type
        @last_heartbeat_details = last_heartbeat_details
      end
    end

    class CancelledError < Failure
      attr_reader :details

      def initialize(message, details: [], raw: nil, cause: nil)
        super(message, raw: raw, cause: cause)

        @details = details
      end
    end

    class TerminatedError < Failure; end

    class ServerError < Failure
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
      attr_reader :last_heartbeat_details

      def initialize(message, last_heartbeat_details: [], raw: nil, cause: nil)
        super(message, raw: raw, cause: cause)

        @last_heartbeat_details = last_heartbeat_details
      end
    end

    class ActivityError < Failure
      attr_reader :scheduled_event_id,
                  :started_event_id,
                  :identity,
                  :activity_name,
                  :activity_id,
                  :retry_state

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

    class ChildWorkflowError < Failure
      attr_reader :namespace,
                  :workflow_id,
                  :run_id,
                  :workflow_name,
                  :initiated_event_id,
                  :started_event_id,
                  :retry_state

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
