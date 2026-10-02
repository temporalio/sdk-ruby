# frozen_string_literal: true

module Temporalio
  module Converters
    # Driver-defined reference to an externally stored payload, used to retrieve it later.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!visibility private
    class StorageDriverClaim
      # @return [Hash<String, String>] Data the driver needs to retrieve the payload. This is written into history, so
      #   it must contain everything required for retrieval and must not contain secrets.
      attr_reader :claim_data

      # Create a claim.
      #
      # @param claim_data [Hash<String, String>] Data identifying the stored payload.
      def initialize(claim_data)
        @claim_data = claim_data
      end

      # @param other [Object] Value to compare with.
      # @return [Boolean] Whether the other value is a claim identifying the same stored payload.
      def ==(other)
        other.is_a?(StorageDriverClaim) && claim_data == other.claim_data
      end

      alias eql? ==

      # @return [Integer] Hash derived from the claim data.
      def hash
        claim_data.hash
      end
    end
  end
end
