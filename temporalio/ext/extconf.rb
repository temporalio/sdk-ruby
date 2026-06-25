# frozen_string_literal: true

require 'mkmf'
require 'rb_sys/mkmf'

create_rust_makefile('temporalio/temporalio_bridge') do |r|
  # Opt-in FIPS build. --no-default-features drops the default `tls-ring` so
  # `ring` is not compiled alongside aws-lc-rs.
  if ENV['TEMPORALIO_FIPS'] == '1'
    r.features = %w[fips]
    r.extra_cargo_args = %w[--no-default-features]
  end
end
