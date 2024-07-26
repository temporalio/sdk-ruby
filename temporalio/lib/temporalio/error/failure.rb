# frozen_string_literal: true

require 'temporalio/error'

module Temporalio
  class Error
    # Base class for all Temporal serializable failures.
    class Failure < Error
      # @return [Api::Failure::V1::Failure, nil] Raw gRPC failure if this was converted from one.
      attr_reader :raw

      # Create failure.
      #
      # @param message [String] Message string.
      # @param cause [Exception, nil] Cause of this exception.
      # @param raw [Api::Failure::V1::Failure, nil] Raw gRPC value if any.
      def initialize(message, cause: nil, raw: nil)
        super(message)

        @cause = cause
        @raw = raw
      end

      # @return [Exception, nil] Cause of the failure.
      def cause
        @cause || super
      end
    end
  end
end
