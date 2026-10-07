# frozen_string_literal: true

require 'temporalio/converters/storage_driver'

module Temporalio
  module Converters
    # Configuration for offloading large payloads to an external storage system.
    #
    # This is validated when constructed rather than when used, so a misconfiguration surfaces at startup instead of on
    # the first payload large enough to offload.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!visibility private
    class ExternalStorage
      # Shared with every other SDK, so the same payload offloads regardless of which one wrote it.
      DEFAULT_PAYLOAD_SIZE_THRESHOLD = 256 * 1024

      # @return [Array<StorageDriver>] Drivers available for storing and retrieving payloads.
      attr_reader :drivers

      # @return [Proc] Selector choosing which driver stores each payload. Called with a
      #   {StorageDriverSelectContext} and a payload, returning a {StorageDriver} or nil to pass the payload through.
      #   Only called for payloads that meet {#payload_size_threshold}, and must return one of {#drivers} or nil.
      attr_reader :driver_selector

      # @return [Integer] Minimum encoded payload size, in bytes, that is offloaded. Payloads at or above this size are
      #   offloaded; smaller ones are left inline. Zero offloads every payload.
      attr_reader :payload_size_threshold

      # Create external storage configuration.
      #
      # @param drivers [Array<StorageDriver>] Drivers available for storing and retrieving payloads. At least one is
      #   required, and every driver must have a unique, non-empty name. Retrieval routes by the name recorded in
      #   history, so a driver must remain configured for as long as any payload it stored can still be read.
      # @param driver_selector [Proc, nil] Selector choosing which driver stores each payload. Required when more than
      #   one driver is given; with a single driver it may be nil, in which case that driver stores every eligible
      #   payload.
      # @param payload_size_threshold [Integer] Minimum encoded payload size, in bytes, to offload. Must be a
      #   non-negative Integer.
      def initialize(drivers:, driver_selector: nil, payload_size_threshold: DEFAULT_PAYLOAD_SIZE_THRESHOLD)
        raise ArgumentError, 'At least one driver is required' if drivers.empty?

        unless payload_size_threshold.is_a?(Integer) && payload_size_threshold >= 0
          raise ArgumentError, 'payload_size_threshold must be a non-negative Integer'
        end

        if drivers.size > 1 && driver_selector.nil?
          raise ArgumentError, 'driver_selector is required when more than one driver is given'
        end

        @drivers_by_name = {}
        drivers.each do |driver|
          name = driver.name
          # The name is the routing key written into history and is written to a string proto field, so anything but
          # a non-empty String cannot be resolved on read. A Symbol in particular passes a bare empty? check.
          raise ArgumentError, 'Driver name must be a non-empty String' unless name.is_a?(String) && !name.empty?
          raise ArgumentError, "Multiple drivers given with name '#{name}'" if @drivers_by_name.key?(name)

          @drivers_by_name[name] = driver
        end
        @drivers_by_name.freeze

        @drivers = drivers.dup.freeze
        # Normalized so callers never have to distinguish the single-driver case.
        @driver_selector = driver_selector || ->(_context, _payload) { @drivers.first }
        @payload_size_threshold = payload_size_threshold
      end

      # Get the driver registered under the given name.
      #
      # @param name [String] Driver name recorded in the payload reference.
      # @return [StorageDriver, nil] The driver, or nil if none is registered under that name.
      def driver(name)
        @drivers_by_name[name]
      end
    end
  end
end
