# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  Priority = Data.define(
    :priority_key
  )

  # Priority contains metadata that controls relative ordering of task processing when tasks are
  # backlogged in a queue. Initially, Priority will be used in activity and workflow task
  # queues, which are typically where backlogs exist. Priority is (for now) attached to
  # workflows and activities. Activities and child workflows inherit Priority from the workflow
  # that created them, but may override fields when they are started or modified. For each field
  # of a Priority on an activity/workflow, not present or equal to zero/empty string means to
  # inherit the value from the calling workflow, or if there is no calling workflow, then use
  # the default (documented on the field).
  #
  # The overall semantics of Priority are:
  # 1. First, consider "priority_key": lower number goes first.
  # (more will be added here later).
  #
  # @!attribute priority_key
  #   @return [Integer, nil] The priority key, which is a positive integer from 1 to n, where
  #     smaller integers correspond to higher priorities (tasks run sooner). In general, tasks in a
  #     queue should be processed in close to priority order, although small deviations are possible.
  #     The maximum priority value (minimum priority) is determined by server configuration, and
  #     defaults to 5.
  #
  #     The default priority is (min+max)/2. With the default max of 5 and min of 1, that comes
  #     out to 3.
  class Priority
    # @!visibility private
    def self._from_proto(priority)
      return default if priority.nil?

      new(priority_key: priority.priority_key.zero? ? nil : priority.priority_key)
    end

    # The default priority instance.
    #
    # @return [Priority] The default priority
    def self.default
      @default ||= new(priority_key: nil)
    end

    # @!visibility private
    def _to_proto
      return nil if priority_key.nil?

      Temporalio::Api::Common::V1::Priority.new(priority_key: priority_key || 0)
    end

    # @return [Boolean] True if this priority is empty/default
    def empty?
      priority_key.nil?
    end
  end
end
