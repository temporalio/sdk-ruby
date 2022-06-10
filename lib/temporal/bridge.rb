require 'rutie'

BRIDGE_DIR = File.expand_path('../../bridge/src', File.dirname(__FILE__))

module Temporal
  module Bridge
    # TODO: Expand this into more specific error types
    Error = Class.new(StandardError);

    Rutie.new(:bridge).init('init_bridge', BRIDGE_DIR)
  end
end
