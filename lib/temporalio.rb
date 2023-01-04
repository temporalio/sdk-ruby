# Protoc wants all of its generated files on the LOAD_PATH
$LOAD_PATH << File.expand_path('./gen', File.dirname(__FILE__))

require 'temporalio/activity'
require 'temporalio/bridge'
require 'temporalio/client'
require 'temporalio/connection'
require 'temporalio/version'
require 'temporalio/worker'

module Temporalio
end
