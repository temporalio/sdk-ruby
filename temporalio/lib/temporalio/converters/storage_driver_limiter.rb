# frozen_string_literal: true

module Temporalio
  module Converters
    # Bounds how many external storage requests are in flight at once. The SDK supplies one on
    # {StorageDriverStoreContext} and {StorageDriverRetrieveContext}; a driver calls it rather than
    # implementing it.
    #
    # A driver is handed a whole batch and decides for itself how many requests to make of it, so the limit is
    # cooperative: a driver that never calls {#permit} makes requests that no limit counts, and the SDK warns when
    # it detects that.
    #
    # @note WARNING: This API is experimental and may change in the future.
    #
    # @!visibility private
    class StorageDriverLimiter
      # Hold a permit for the duration of the given block, waiting for one to be available before the block runs
      # and releasing it when the block returns or raises.
      #
      # Take one permit per request, not one around a whole batch: wrapping a whole fan out in a single permit
      # satisfies this signature while quietly defeating the limit. Do not take a permit while holding one.
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
