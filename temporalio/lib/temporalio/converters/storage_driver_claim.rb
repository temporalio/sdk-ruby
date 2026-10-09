# frozen_string_literal: true

module Temporalio
  module Converters
    StorageDriverClaim = Data.define(:claim_data)

    # Driver-defined reference to an externally stored payload, used to retrieve it later.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!attribute [r] claim_data
    #   @return [Hash<String, String>] Data the driver needs to retrieve the payload. This is written into history, so
    #     it must contain everything required for retrieval and must not contain secrets.
    #
    # @!visibility private
    class StorageDriverClaim
      # Create a claim.
      #
      # @param claim_data [Hash<String, String>] Data identifying the stored payload.
      def initialize(claim_data:)
        # Copied and frozen because a claim is compared and hashed by this data, so a later mutation would silently
        # change its identity. The values are copied individually because freezing the Hash leaves them mutable in
        # place and still aliased to the caller's objects.
        # steep:ignore:start
        super(claim_data: claim_data.transform_values { |value| value.dup.freeze }.freeze)
        # steep:ignore:end
      end
    end
  end
end
