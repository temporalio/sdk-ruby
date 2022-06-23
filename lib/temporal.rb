# Protoc wants all of its generated files on the LOAD_PATH
$LOAD_PATH << File.expand_path('./gen', File.dirname(__FILE__))

require 'temporal/bridge'
require 'temporal/version'

module Temporal
end
