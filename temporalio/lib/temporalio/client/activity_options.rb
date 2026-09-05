# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/internal/proto_utils'

module Temporalio
  class Client
    # The activity options that {ActivityHandle#update_options} can change.
    #
    # Updates are created from the keys below, via {Key#value_set} to set an option or
    # {Key#value_unset} to clear it. An option with no update is left untouched.
    #
    # WARNING: Standalone Activities are experimental.
    module ActivityOptions
      # Typed key for one updatable activity option. Use the keys on {ActivityOptions} rather than
      # constructing these directly.
      class Key
        # @return [String] Field-mask path this key updates.
        attr_reader :name

        # @!visibility private
        def initialize(name, &to_proto)
          @name = name
          @to_proto = to_proto
          freeze
        end

        # Create an update that sets this option to the given value.
        #
        # @param value [Object] Value to set. Cannot be nil.
        # @return [Update] Created update.
        def value_set(value)
          raise ArgumentError, 'Value cannot be nil, use value_unset' if value.nil?

          Update.new(self, value)
        end

        # Create an update that clears this option server-side.
        #
        # @return [Update] Created update.
        def value_unset
          Update.new(self, nil)
        end

        # @!visibility private
        def _apply(proto, value)
          @to_proto.call(proto, value)
        end
      end

      # A single change to an activity's options that can be separately applied.
      class Update
        # @return [Key] Key this update applies to.
        attr_reader :key

        # @return [Object, nil] Value to set, or `nil` to clear the option.
        attr_reader :value

        # Create an update. Users may find it easier to use {Key#value_set} and {Key#value_unset}.
        #
        # @param key [Key] Key to update.
        # @param value [Object, nil] Value to set, or nil to clear the option.
        def initialize(key, value)
          raise ArgumentError, 'Key must be a key' unless key.is_a?(Key)

          @key = key
          @value = value
          freeze
        end
      end

      # @return [Key] New task queue.
      TASK_QUEUE = Key.new('task_queue.name') do |proto, value|
        proto.task_queue = Api::TaskQueue::V1::TaskQueue.new(name: value.to_s)
      end

      # @return [Key] New schedule-to-close timeout in seconds.
      SCHEDULE_TO_CLOSE_TIMEOUT = Key.new('schedule_to_close_timeout') do |proto, value|
        proto.schedule_to_close_timeout = Internal::ProtoUtils.seconds_to_duration(value)
      end

      # @return [Key] New schedule-to-start timeout in seconds.
      SCHEDULE_TO_START_TIMEOUT = Key.new('schedule_to_start_timeout') do |proto, value|
        proto.schedule_to_start_timeout = Internal::ProtoUtils.seconds_to_duration(value)
      end

      # @return [Key] New start-to-close timeout in seconds.
      START_TO_CLOSE_TIMEOUT = Key.new('start_to_close_timeout') do |proto, value|
        proto.start_to_close_timeout = Internal::ProtoUtils.seconds_to_duration(value)
      end

      # @return [Key] New heartbeat timeout in seconds.
      HEARTBEAT_TIMEOUT = Key.new('heartbeat_timeout') do |proto, value|
        proto.heartbeat_timeout = Internal::ProtoUtils.seconds_to_duration(value)
      end

      # @return [Key] New start delay in seconds.
      START_DELAY = Key.new('start_delay') do |proto, value|
        proto.start_delay = Internal::ProtoUtils.seconds_to_duration(value)
      end

      # @return [Key] New retry policy.
      RETRY_POLICY = Key.new('retry_policy') do |proto, value|
        proto.retry_policy = value._to_proto
      end

      # @return [Key] New priority.
      PRIORITY = Key.new('priority') do |proto, value|
        proto.priority = value._to_proto
      end
    end
  end
end
