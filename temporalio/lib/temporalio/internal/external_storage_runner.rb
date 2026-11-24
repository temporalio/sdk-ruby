# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/cancellation'
require 'temporalio/converters/storage_driver_claim'
require 'temporalio/converters/storage_driver_retrieve_context'
require 'temporalio/converters/storage_driver_select_context'
require 'temporalio/converters/storage_driver_store_context'
require 'temporalio/error'
require 'temporalio/internal/external_storage_references'
require 'temporalio/internal/storage_operation_metrics'

module Temporalio
  module Internal
    # Stores large payloads in external storage and fetches them back.
    #
    # Storing replaces each payload at or above the size threshold with a reference to what a driver stored. Retrieving
    # swaps references back for the payloads they point at. Payloads are expected to already be codec-encoded when
    # stored, and are returned still encoded when retrieved.
    #
    # Each driver gets one batched request per call, and requests to different drivers run one after another.
    # Concurrency limits are not enforced. Drivers get the contexts' default limiter, which grants every permit.
    #
    # @!visibility private
    class ExternalStorageRunner
      MONOTONIC_CLOCK = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      private_constant :MONOTONIC_CLOCK

      # @param storage [Converters::ExternalStorage, nil] Configured storage. When nil, storing does nothing and
      #   retrieving raises if it finds a reference, so a reference is never mistaken for an ordinary payload.
      # @param namespace [String, nil] Namespace of the client or worker storing through this runner, or nil when it is
      #   not known.
      # @param clock [Proc] Returns monotonic seconds, read around each driver call to time it.
      def initialize(storage, namespace:, clock: MONOTONIC_CLOCK)
        @storage = storage
        @namespace = namespace
        @clock = clock
      end

      # @param payloads [Array<Api::Common::V1::Payload>] Codec-encoded payloads. Not mutated.
      # @param target [Converters::StorageDriverWorkflowInfo, Converters::StorageDriverActivityInfo, nil] The
      #   execution every one of these payloads is stored on behalf of, or nil when there is none.
      # @param metrics [StorageOperationMetrics, nil] Records each driver call that stores payloads.
      # @return [Array<Api::Common::V1::Payload>] Payloads with every eligible one replaced by a reference.
      def store(payloads, target: nil, metrics: nil)
        storage = @storage
        return payloads unless storage

        select_context = Converters::StorageDriverSelectContext.new(
          target:, cancellation: Cancellation.new, namespace: @namespace
        )

        # Driver => [[index, serialized payload], ...] for each payload that driver stores
        payloads_by_driver = Hash.new { |hash, driver| hash[driver] = [] }
        payloads.each_with_index do |payload, index|
          serialized = payload.to_proto
          next if serialized.bytesize < storage.payload_size_threshold

          driver = raise_as_storage_error('External storage driver selector failed') do
            storage.driver_selector.call(select_context, payload)
          end
          next unless driver

          # Checked by identity, so a driver built to look like a registered one is rejected.
          unless storage.driver(driver.name).equal?(driver)
            raise Error::ExternalStorageError,
                  "External storage driver selector returned a driver that is not registered: #{driver.inspect}"
          end

          payloads_by_driver[driver] << [index, serialized]
        end

        result = payloads.dup
        payloads_by_driver.each do |driver, indexes_and_serialized|
          context = Converters::StorageDriverStoreContext.new(
            target:, cancellation: Cancellation.new, namespace: @namespace
          )
          # Drivers get copies, since a driver may keep a payload after returning and the SDK modifies some payloads in
          # place
          copies = indexes_and_serialized.map { |_index, serialized| Api::Common::V1::Payload.decode(serialized) }
          start_time = @clock.call
          claims = raise_as_storage_error("External storage driver '#{driver.name}' failed to store payloads") do
            driver.store(context, copies)
          end
          end_time = @clock.call
          check_driver_result(driver, 'store', indexes_and_serialized.size, claims, Converters::StorageDriverClaim)
          metrics&.record(
            driver_name: driver.name,
            payload_count: claims.size,
            total_size_bytes: indexes_and_serialized.sum { |_index, serialized| serialized.bytesize },
            start_time:,
            end_time:
          )

          indexes_and_serialized.zip(claims) do |(index, serialized), claim|
            result[index] = ExternalStorageReferences.create_reference_payload(
              driver_name: driver.name, claim_data: claim.claim_data, original_size_bytes: serialized.bytesize
            )
          end
        end
        result
      end

      # @param payloads [Array<Api::Common::V1::Payload>] Payloads that may contain references. Not mutated.
      # @param metrics [StorageOperationMetrics, nil] Records each driver call that retrieves payloads.
      # @return [Array<Api::Common::V1::Payload>] Payloads with every reference replaced by what it points at.
      # @raise [Error::ExternalStorageNotConfiguredError] If there is a reference but no storage is configured.
      # @raise [Error::ExternalStorageError] If a reference cannot be read or retrieved.
      def retrieve(payloads, metrics: nil)
        storage = @storage
        # Driver => [[index, claim], ...] for each reference that driver stored. Every driver is looked up here, so an
        # unregistered name fails before any request is made.
        claims_by_driver = Hash.new { |hash, driver| hash[driver] = [] }
        payloads.each_with_index do |payload, index|
          reference = ExternalStorageReferences.parse_reference(payload)
          next unless reference
          raise Error::ExternalStorageNotConfiguredError unless storage

          driver = storage.driver(reference.driver_name)
          unless driver
            raise Error::ExternalStorageError,
                  "No external storage driver registered with name '#{reference.driver_name}'"
          end

          claims_by_driver[driver] << [index, Converters::StorageDriverClaim.new(claim_data: reference.claim_data.to_h)]
        end

        result = payloads.dup
        claims_by_driver.each do |driver, indexes_and_claims|
          context = Converters::StorageDriverRetrieveContext.new(cancellation: Cancellation.new)
          start_time = @clock.call
          retrieved = raise_as_storage_error("External storage driver '#{driver.name}' failed to retrieve payloads") do
            driver.retrieve(context, indexes_and_claims.map { |_index, claim| claim })
          end
          end_time = @clock.call
          check_driver_result(driver, 'retrieve', indexes_and_claims.size, retrieved, Api::Common::V1::Payload)
          metrics&.record(
            driver_name: driver.name,
            payload_count: retrieved.size,
            total_size_bytes: retrieved.sum { |payload| payload.to_proto.bytesize },
            start_time:,
            end_time:
          )

          indexes_and_claims.zip(retrieved) { |(index, _claim), payload| result[index] = payload }
        end
        result
      end

      private

      def raise_as_storage_error(failure_message)
        yield
      rescue Error::ExternalStorageError, Error::CanceledError
        raise
      rescue StandardError => e
        raise Error::ExternalStorageError, "#{failure_message}: #{e.message}"
      end

      def check_driver_result(driver, operation, requested, returned, expected_item_class)
        unless returned.is_a?(Array) && returned.size == requested
          raise Error::ExternalStorageError,
                "External storage driver '#{driver.name}' #{operation} was given #{requested} item(s) but " \
                "returned #{returned.is_a?(Array) ? returned.size : returned.inspect}"
        end

        returned.each do |item|
          next if item.is_a?(expected_item_class)

          raise Error::ExternalStorageError,
                "External storage driver '#{driver.name}' #{operation} returned #{item.inspect} instead of a " \
                "#{expected_item_class}"
        end
      end
    end
  end
end
