# frozen_string_literal: true

module Temporalio
  module Converters
    # Bounds how many external storage requests are in flight at once. The SDK supplies one on
    # {StorageDriverStoreContext} and {StorageDriverRetrieveContext}; a driver calls it rather than
    # implementing it.
    #
    # The SDK cannot see the requests a driver makes, so the limit works only if the driver takes a permit for
    # each request.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!visibility private
    class StorageDriverLimiter
      # Hold a permit for the duration of the given block, waiting for one to be available before the block runs
      # and releasing it when the block returns or raises.
      #
      # Wrapping a whole fan out in a single permit satisfies this signature while quietly defeating the limit.
      # Taking a second permit while handling one request, directly or in a helper, deadlocks at the limit:
      # every holder would be waiting for a permit only another holder can release.
      #
      # Waiting for a permit observes the cancellation on the context this limiter came from.
      #
      # @param item [Api::Common::V1::Payload, StorageDriverClaim] What this one request covers: a payload when
      #   storing, a claim when retrieving.
      # @yield The request to make while holding the permit.
      # @return [Object] Whatever the block returned.
      # @raise [Error::CanceledError] If cancelled while waiting for a permit.
      def permit(item, &)
        raise NotImplementedError
      end
    end
  end
end
