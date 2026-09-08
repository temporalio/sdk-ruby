# frozen_string_literal: true

require 'temporalio/internal/proto_utils'
require 'temporalio/priority'
require 'temporalio/retry_policy'

module Temporalio
  class Client
    # The resolved options of a standalone activity execution, as returned by
    # {ActivityHandle#update_options}. Reflects the activity's options as the server resolved them
    # after the update was applied.
    #
    # WARNING: Standalone Activities are experimental.
    ActivityExecutionOptions = Data.define(
      :task_queue,
      :schedule_to_close_timeout,
      :schedule_to_start_timeout,
      :start_to_close_timeout,
      :heartbeat_timeout,
      :retry_policy,
      :priority,
      :start_delay
    ) do
      # @!visibility private
      def self._from_proto(options)
        new(
          task_queue: Internal::ProtoUtils.string_or(options.task_queue&.name, nil),
          schedule_to_close_timeout: Internal::ProtoUtils.duration_to_seconds(options.schedule_to_close_timeout),
          schedule_to_start_timeout: Internal::ProtoUtils.duration_to_seconds(options.schedule_to_start_timeout),
          start_to_close_timeout: Internal::ProtoUtils.duration_to_seconds(options.start_to_close_timeout),
          heartbeat_timeout: Internal::ProtoUtils.duration_to_seconds(options.heartbeat_timeout),
          retry_policy: options.retry_policy ? RetryPolicy._from_proto(options.retry_policy) : nil,
          priority: Priority._from_proto(options.priority),
          start_delay: Internal::ProtoUtils.duration_to_seconds(options.start_delay)
        )
      end
    end
  end
end
