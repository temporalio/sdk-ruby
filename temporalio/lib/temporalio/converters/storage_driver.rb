# frozen_string_literal: true

module Temporalio
  module Converters
    # Base class for storing and retrieving payloads in an external storage system.
    #
    # Payloads at or over the configured size threshold are handed to a driver and replaced on the wire by a small
    # reference, so the payload data itself never reaches the Temporal server.
    #
    # Implementations are called concurrently and must be thread safe. Methods block, and may perform I/O directly.
    # To work a batch concurrently, fan out with threads: threads overlap blocking I/O, since Ruby releases its global
    # lock around it, and they work whether or not the worker is running under a fiber scheduler.
    # {::Fiber.schedule} must not be used, since it raises when the worker is configured with a payload codec thread
    # pool instead of a fiber scheduler. {Temporalio::Worker::ThreadPool} can be used to bound that fan out.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!visibility private
    class StorageDriver
      # Name of this driver instance, unique among the drivers registered on one {ExternalStorage}. This is written
      # into history alongside every payload the driver stores and is used to route retrieval back to the same driver.
      # Renaming a deployed driver makes every payload stored under the old name unretrievable.
      #
      # @return [String] Driver instance name.
      def name
        raise NotImplementedError
      end

      # Identifier for this driver implementation, for example +aws.s3driver+. Unlike {#name}, this is identical across
      # every instance of the same implementation and across SDK languages.
      #
      # @return [String] Driver implementation identifier.
      def type
        raise NotImplementedError
      end

      # Store the given payloads.
      #
      # @param context [StorageDriverStoreContext] Context for this store operation.
      # @param payloads [Enumerable<Api::Common::V1::Payload>] Payloads to store. This value should not be mutated.
      # @return [Array<StorageDriverClaim>] One claim per payload, in the same order.
      def store(context, payloads)
        raise NotImplementedError
      end

      # Retrieve the payloads for the given claims.
      #
      # @param context [StorageDriverRetrieveContext] Context for this retrieve operation.
      # @param claims [Enumerable<StorageDriverClaim>] Claims to retrieve. This value should not be mutated.
      # @return [Array<Api::Common::V1::Payload>] One payload per claim, in the same order.
      def retrieve(context, claims)
        raise NotImplementedError
      end
    end
  end
end
