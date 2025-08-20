# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  Priority = Data.define(
    :priority_key,
    :fairness_key,
    :weight
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
  #
  # @!attribute fairness_key
  #   @return [String, nil] FairnessKey is a short string that's used as a key for a fairness
  #     balancing mechanism. It may correspond to a tenant id, or to a fixed
  #     string like "high" or "low". The default is the empty string.
  #
  #     The fairness mechanism attempts to dispatch tasks for a given key in
  #     proportion to its weight. For example, using a thousand distinct tenant
  #     ids, each with a weight of 1.0 (the default) will result in each tenant
  #     getting a roughly equal share of task dispatch throughput.
  #
  #     Fairness keys are limited to 64 bytes.
  #
  # @!attribute weight
  #   @return [Float, nil] Weight for a task can come from multiple sources for
  #     flexibility. From highest to lowest precedence:
  #     1. Weights for a small set of keys can be overridden in task queue
  #        configuration with an API.
  #     2. It can be attached to the workflow/activity in this field.
  #     3. The default weight of 1.0 will be used.
  #
  #     Weight values are clamped to the range [0.001, 1000].
  class Priority
    # @!visibility private
    def self._from_proto(priority)
      return default if priority.nil?

      new(
        priority_key: priority.priority_key.zero? ? nil : priority.priority_key,
        fairness_key: priority.fairness_key.empty? ? nil : priority.fairness_key,
        weight: priority.fairness_weight.zero? ? nil : priority.fairness_weight
      )
    end

    # The default priority instance.
    #
    # @return [Priority] The default priority
    def self.default
      @default ||= new(priority_key: nil, fairness_key: nil, weight: nil)
    end

    # @!visibility private
    def _to_proto
      return nil if empty?

      Temporalio::Api::Common::V1::Priority.new(
        priority_key: priority_key || 0,
        fairness_key: fairness_key || '',
        fairness_weight: weight || 0.0
      )
    end

    # @return [Boolean] True if this priority is empty/default
    def empty?
      priority_key.nil? && fairness_key.nil? && weight.nil?
    end
  end
end
