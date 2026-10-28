# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/cancellation'
require 'temporalio/converters/storage_driver_claim'
require 'temporalio/converters/storage_driver_limiter'
require 'temporalio/converters/storage_driver_retrieve_context'
require 'temporalio/converters/storage_driver_select_context'
require 'temporalio/converters/storage_driver_store_context'
require 'temporalio/error'
require 'temporalio/internal/external_storage_references'

module Temporalio
  module Internal
    # Stores large payloads in external storage and fetches them back.
    #
    # Storing replaces each payload at or above the size threshold with a reference to what a driver stored. Retrieving
    # swaps references back for the payloads they point at. Payloads are expected to already be codec-encoded when
    # stored, and are returned still encoded when retrieved.
    #
    # Each driver gets one batched request per call, and requests to different drivers run one after another. The
    # configured concurrency limits are not enforced and the driver target is always nil.
    #
    # @!visibility private
    class ExternalStorageRunner
      # @param storage [Converters::ExternalStorage, nil] Configured storage. When nil, storing does nothing and
      #   retrieving raises if it finds a reference, so a reference is never mistaken for an ordinary payload.
      def initialize(storage)
        @storage = storage
      end

      # @param payloads [Array<Api::Common::V1::Payload>] Codec-encoded payloads. Not mutated.
      # @return [Array<Api::Common::V1::Payload>] Payloads with every eligible one replaced by a reference.
      def store(payloads)
        storage = @storage
        return payloads unless storage

        select_context = Converters::StorageDriverSelectContext.new(target: nil, cancellation: Cancellation.new)

        # Driver => [[index, size], ...] for each payload that driver stores
        payloads_by_driver = Hash.new { |hash, driver| hash[driver] = [] }
        payloads.each_with_index do |payload, index|
          size = payload.to_proto.bytesize
          next if size < storage.payload_size_threshold

          driver = storage.driver_selector.call(select_context, payload)
          next unless driver

          # Checked by identity, so a driver built to look like a registered one is rejected.
          unless storage.driver(driver.name).equal?(driver)
            raise Error, "External storage driver selector returned a driver that is not registered: #{driver.inspect}"
          end

          payloads_by_driver[driver] << [index, size]
        end

        result = payloads.dup
        payloads_by_driver.each do |driver, indexes_and_sizes|
          context = Converters::StorageDriverStoreContext.new(
            target: nil, cancellation: Cancellation.new, limiter: UNBOUNDED_LIMITER
          )
          claims = driver.store(context, indexes_and_sizes.map { |index, _size| payloads[index] })
          check_result_count(driver, 'store', indexes_and_sizes.size, claims)

          indexes_and_sizes.zip(claims) do |(index, size), claim|
            result[index] = ExternalStorageReferences.create_reference_payload(
              driver_name: driver.name, claim_data: claim.claim_data, original_size_bytes: size
            )
          end
        end
        result
      end

      # @param payloads [Array<Api::Common::V1::Payload>] Payloads that may contain references. Not mutated.
      # @return [Array<Api::Common::V1::Payload>] Payloads with every reference replaced by what it points at.
      # @raise [Error::ExternalStorageNotConfiguredError] If there is a reference but no storage is configured.
      def retrieve(payloads)
        storage = @storage
        # Driver => [[index, claim], ...] for each reference that driver stored. Every driver is looked up here, so an
        # unregistered name fails before any request is made.
        claims_by_driver = Hash.new { |hash, driver| hash[driver] = [] }
        payloads.each_with_index do |payload, index|
          reference = ExternalStorageReferences.parse_reference(payload)
          next unless reference
          raise Error::ExternalStorageNotConfiguredError unless storage

          driver = storage.driver(reference.driver_name)
          raise Error, "No external storage driver registered with name '#{reference.driver_name}'" unless driver

          claims_by_driver[driver] << [index, Converters::StorageDriverClaim.new(claim_data: reference.claim_data.to_h)]
        end

        result = payloads.dup
        claims_by_driver.each do |driver, indexes_and_claims|
          context = Converters::StorageDriverRetrieveContext.new(
            cancellation: Cancellation.new, limiter: UNBOUNDED_LIMITER
          )
          retrieved = driver.retrieve(context, indexes_and_claims.map { |_index, claim| claim })
          check_result_count(driver, 'retrieve', indexes_and_claims.size, retrieved)

          indexes_and_claims.zip(retrieved) { |(index, _claim), payload| result[index] = payload }
        end
        result
      end

      private

      def check_result_count(driver, operation, requested, returned)
        return if returned.is_a?(Array) && returned.size == requested

        raise Error, "External storage driver '#{driver.name}' #{operation} was given #{requested} item(s) but " \
                     "returned #{returned.is_a?(Array) ? returned.size : returned.inspect}"
      end

      # Grants every permit immediately, since concurrency limits are not enforced yet.
      class UnboundedLimiter < Converters::StorageDriverLimiter
        def permit(_item)
          yield
        end
      end

      UNBOUNDED_LIMITER = UnboundedLimiter.new
      private_constant :UnboundedLimiter, :UNBOUNDED_LIMITER
    end
  end
end
