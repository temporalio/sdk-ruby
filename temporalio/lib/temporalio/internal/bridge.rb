# frozen_string_literal: true

# Use Ruby-version-specific Rust library if present. When the gem is compiled
# via the cross-gem action, it is placed in a version specific directory. E.g.
# for the Linux gem as of this writing, there will be files at:
#   * temporalio/internal/bridge/3.2/temporalio_bridge.so
#   * temporalio/internal/bridge/3.3/temporalio_bridge.so
#   * temporalio/internal/bridge/3.4/temporalio_bridge.so
# We fallback to just temporalio/internal/bridge/temporalio_bridge.so because
# rake compile puts it there during manual build/development.
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

      # On FIPS builds the native crypto backend (aws-lc-rs) is FIPS-validated, but the SDK still relies on Ruby's
      # own OpenSSL for `SecureRandom` (request IDs) and the default worker build id digest. Those are only
      # FIPS-backed if Ruby was built against a FIPS-enabled OpenSSL with FIPS mode active. If not, warn once rather
      # than raise. No-op on non-FIPS builds.
      def self.assert_fips_compatibility!
        return unless FIPS
        return if @fips_compatibility_checked

        @fips_compatibility_checked = true
        require 'openssl'
        return if OpenSSL.fips_mode

        warn 'temporalio: built for FIPS (aws-lc-rs) but Ruby OpenSSL is not in FIPS mode; SecureRandom and the ' \
             'default worker build id will not use a FIPS-validated module. Build Ruby against a FIPS-enabled ' \
             'OpenSSL and enable FIPS mode for full compliance.'
      rescue StandardError
        # Some OpenSSL builds cannot report fips_mode; do not block usage over an unanswerable check.
        nil
      end

      def self.fibers_supported
        # We do not allow fibers on < 3.3 due to a bug we still need to dig
        # into: https://github.com/temporalio/sdk-ruby/issues/162
        major, minor = RUBY_VERSION.split('.').take(2).map(&:to_i)
        !major.nil? && !minor.nil? && (major > 3 || (major == 3 && minor >= 3))
      end
    end
  end
end
