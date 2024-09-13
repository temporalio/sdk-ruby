# frozen_string_literal: true

module Temporalio
  module Internal
    module Bridge
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
