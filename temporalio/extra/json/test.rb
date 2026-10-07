# frozen_string_literal: true

require 'json'

abort "Expected JSON 3, loaded #{JSON::VERSION}" unless JSON::VERSION.to_i == 3

puts "Testing JSON #{JSON::VERSION} on Ruby #{RUBY_VERSION}"
ARGV.push('--name', '/Converters::JSONPlainTest|test_json_additions_replay/')

require_relative '../../test/converters/json_plain_test'
require_relative '../../test/worker/workflow_replayer_test'
