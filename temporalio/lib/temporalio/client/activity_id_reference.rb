# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/interceptor'
require 'temporalio/error'

module Temporalio
  class Client
    # Reference to an existing activity by its workflow ID, run ID, and activity ID.
    class ActivityIDReference
      # @return [String] ID for the workflow.
      attr_reader :workflow_id

      # @return [String, nil] Run ID for the workflow.
      attr_reader :run_id

      # @return [String] ID for the activity.
      attr_reader :activity_id

      # Create an activity ID reference.
      #
      # @param workflow_id [String] ID for the workflow.
      # @param run_id [String, nil] Run ID for the workflow.
      # @param activity_id [String] ID for the workflow.
      def initialize(workflow_id:, run_id:, activity_id:)
        @workflow_id = workflow_id
        @run_id = run_id
        @activity_id = activity_id
      end
    end
  end
end
