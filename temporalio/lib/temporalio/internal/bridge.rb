# frozen_string_literal: true

# Use Ruby-version-specific Rust library if present
begin
  RUBY_VERSION =~ /(\d+\.\d+)/
  require "temporalio/internal/bridge/#{Regexp.last_match(1)}/temporalio_bridge"
rescue LoadError
  require 'temporalio/internal/bridge/temporalio_bridge'
end

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
