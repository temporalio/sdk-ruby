# frozen_string_literal: true

module Temporalio
  module Internal
    # @!visibility private
    module Bridge
      # @!visibility private
      def self.async_call
        queue = Queue.new
        yield queue
        result = queue.pop
        raise result if result.is_a?(Exception)

        result
      end
    end
  end
end
