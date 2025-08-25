# frozen_string_literal: true

require 'temporalio/envconfig'
require 'temporalio/version'
require 'temporalio/versioning_override'

# Temporal Ruby SDK. See the README at https://github.com/temporalio/sdk-ruby.
module Temporalio
  # @!visibility private
  def self._root_file_path
    __FILE__
  end
end
