# frozen_string_literal: true

require 'temporalio/client/interceptor'
require 'temporalio/client/schedule'

module Temporalio
  class Client
    # Handle for interacting with a schedule. This is usually created via {Client.create_schedule} or
    # {Client.schedule_handle}.
    class ScheduleHandle
      # @return [String] ID of the schedule.
      attr_reader :id

      # @!visibility private
      def initialize(client:, id:)
        @client = client
        @id = id
      end

      # Backfill the schedule by going through the specified time periods as if they passed right now.
      #
      # @param backfills [Array<Schedule::Backfill>] Backfill periods.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @raise [Error::RPCError] RPC error from call.
      def backfill(
        *backfills,
        rpc_options: nil
      )
        raise ArgumentError, 'At least one backfill required' if backfills.empty?

        @client._impl.backfill_schedule(Interceptor::BackfillScheduleInput.new(
                                          id:,
                                          backfills:,
                                          rpc_options:
                                        ))
      end

      # Delete this schedule.
      #
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @raise [Error::RPCError] RPC error from call.
      def delete(rpc_options: nil)
        @client._impl.delete_schedule(Interceptor::DeleteScheduleInput.new(
                                        id:,
                                        rpc_options:
                                      ))
      end

      # Fetch this schedule's description.
      #
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @return [Schedule::Description] Schedule description.
      # @raise [Error::RPCError] RPC error from call.
      def describe(rpc_options: nil)
        @client._impl.describe_schedule(Interceptor::DescribeScheduleInput.new(
                                          id:,
                                          rpc_options:
                                        ))
      end

      # Pause the schedule and set a note.
      #
      # @param note [String] Note to set on the schedule.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @raise [Error::RPCError] RPC error from call.
      def pause(note: 'Paused via Ruby SDK', rpc_options: nil)
        @client._impl.pause_schedule(Interceptor::PauseScheduleInput.new(
                                       id:,
                                       note:,
                                       rpc_options:
                                     ))
      end

      # Trigger an action on this schedule to happen immediately.
      #
      # @param overlap [Schedule::OverlapPolicy, nil] If set, overrides the schedule's overlap policy.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @raise [Error::RPCError] RPC error from call.
      def trigger(overlap: nil, rpc_options: nil)
        @client._impl.trigger_schedule(Interceptor::TriggerScheduleInput.new(
                                         id:,
                                         overlap:,
                                         rpc_options:
                                       ))
      end

      # Unpause the schedule and set a note.
      #
      # @param note [String] Note to set on the schedule.
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      #
      # @raise [Error::RPCError] RPC error from call.
      def unpause(note: 'Unpaused via Ruby SDK', rpc_options: nil)
        @client._impl.unpause_schedule(Interceptor::UnpauseScheduleInput.new(
                                         id:,
                                         note:,
                                         rpc_options:
                                       ))
      end

      # Update a schedule using a callback to build the update from the description.
      #
      # NOTE: In future versions, the callback may be invoked multiple times in a conflict-resolution loop.
      #
      # @param rpc_options [RPCOptions, nil] Advanced RPC options.
      # @yield Block called to obtain the update.
      # @yieldparam [Schedule::Update::Input] Parameter to the block that contains a description with the schedule to be
      #   updated.
      # @yieldreturn [Schedule::Update, nil] The update to apply, or `nil` to not perform an update.
      #
      # @raise [Error::RPCError] RPC error from call.
      def update(rpc_options: nil, &updater)
        @client._impl.update_schedule(Interceptor::UpdateScheduleInput.new(
                                        id:,
                                        updater:,
                                        rpc_options:
                                      ))
      end
    end
  end
end
