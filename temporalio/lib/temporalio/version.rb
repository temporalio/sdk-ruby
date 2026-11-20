# frozen_string_literal: true

module Temporalio
  # The fork's gems keep upstream's version on purpose (see fork/README.md): a consumer's lockfile and gemset then still
  # resolve from rubygems.org, and only the gem files themselves are swapped for the fork's.
  VERSION = '1.11.0'
end
