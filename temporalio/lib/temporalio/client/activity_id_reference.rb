# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client/interceptor'
require 'temporalio/error'

module Temporalio
  class Client
    # Reference to an activity for use with {Client#async_activity_handle}. There are two shapes,
    # depending on whether the activity is run in a workflow, or as a standalone activity.
    #
    # 1. Activity run in a workflow -- use {ActivityIDReference#initialize}:
    #    `ActivityIDReference.new(workflow_id:, run_id:, activity_id:)`.
    #
    # 2. Standalone Activity (started  via {Client#start_activity}): use the class factory
    #    {ActivityIDReference.for_standalone}: `ActivityIDReference.for_standalone(activity_id:, activity_run_id:)`.
    class ActivityIDReference
      # @return [String] ID for the activity.
      attr_reader :activity_id

      # @return [String, nil] Activity run ID. Set only for standalone activity references.
      attr_reader :activity_run_id

      # @return [String, nil] ID for the workflow. Set only for workflow-run activity references.
      attr_reader :workflow_id

      # @return [String, nil] Run ID for the workflow. Set only for workflow-run activity references.
      attr_reader :run_id

      # Construct a standalone activity reference.
      #
      # WARNING: Standalone Activities are experimental.
      #
      # @param activity_id [String] ID for the activity.
      # @param activity_run_id [String, nil] Run ID for the activity execution. nil targets the latest run.
      # @return [ActivityIDReference] A reference suitable for {Client#async_activity_handle}.
      def self.for_standalone(activity_id:, activity_run_id: nil)
        allocate.tap do |ref|
          ref.instance_variable_set(:@activity_id, activity_id)
          ref.instance_variable_set(:@activity_run_id, activity_run_id)
          ref.instance_variable_set(:@workflow_id, nil)
          ref.instance_variable_set(:@run_id, nil)
        end
      end

      # Construct a workflow-run activity reference.
      #
      # @param workflow_id [String] ID for the workflow.
      # @param run_id [String, nil] Run ID for the workflow.
      # @param activity_id [String] ID for the activity.
      # @return [ActivityIDReference] A reference suitable for {Client#async_activity_handle}.
      def initialize(workflow_id:, run_id:, activity_id:)
        @workflow_id = workflow_id
        @run_id = run_id
        @activity_id = activity_id
        @activity_run_id = nil
      end

      # @return [Boolean] True if this reference is the standalone-form (activity_run_id without workflow_id).
      #   WARNING: Standalone Activities are experimental.
      def standalone?
        @workflow_id.nil?
      end
    end
  end
end
