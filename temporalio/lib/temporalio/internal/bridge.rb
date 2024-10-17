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
    module Bridge
      def self.assert_fiber_compatibility!
        return unless Fiber.current_scheduler && !fibers_supported

        raise 'Temporal SDK only supports fibers with Ruby 3.3 and newer, ' \
              'see https://github.com/temporalio/sdk-ruby/issues/162'
      end

      def self.fibers_supported
        # We do not allow fibers on < 3.3 due to a bug we still need to dig
        # into: https://github.com/temporalio/sdk-ruby/issues/162
        major, minor = RUBY_VERSION.split('.').take(2).map(&:to_i)
        !major.nil? && major >= 3 && !minor.nil? && minor >= 3
      end
    end
  end
end
