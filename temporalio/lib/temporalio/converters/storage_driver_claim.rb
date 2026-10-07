# frozen_string_literal: true

module Temporalio
  module Converters
    StorageDriverClaim = Data.define(:claim_data)

    # Driver-defined reference to an externally stored payload, used to retrieve it later.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!visibility private
    class StorageDriverClaim
      # Create a claim.
      #
      # @param claim_data [Hash<String, String>] Key/value pairs the driver needs to retrieve the payload later. This
      #   is written into history, so it must contain everything required for retrieval and must not contain secrets.
      def initialize(claim_data:)
        # Copied and frozen because a claim is compared and hashed by this data, so a later mutation would silently
        # change its identity.
        # steep:ignore:start
        super(claim_data: claim_data.dup.freeze)
        # steep:ignore:end
      end
    end
  end
end
