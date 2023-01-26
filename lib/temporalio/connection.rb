require 'temporalio/bridge'
require 'temporalio/connection/test_service'
require 'temporalio/connection/workflow_service'
require 'temporalio/errors'
require 'temporalio/runtime'
require 'uri'

module Temporalio
  # A connection to the Temporal server.
  #
  # This is used to instantiate a {Temporalio::Client}. But it also can be used for a direct
  # interaction with the API via one of the services (e.g. {#workflow_service}).
  class Connection
    # @api private
    attr_reader :core_connection

    # @param host [String] `host:port` for the Temporal server. For local development, this is
    #   often `"localhost:7233"`.
    def initialize(host)
      url = parse_url(host)
      runtime = Temporalio::Runtime.instance
      @core_connection = Temporalio::Bridge::Connection.connect(runtime.core_runtime, url)
    end

    # Get an object for making WorkflowService RPCs.
    #
    # @return [Temporalio::Connection::WorkflowService]
    def workflow_service
      @workflow_service ||= Temporalio::Connection::WorkflowService.new(core_connection)
    end

    # Get an object for making TestService RPCs.
    #
    # @return [Temporalio::Connection::TestService]
    def test_service
      @test_service ||= Temporalio::Connection::TestService.new(core_connection)
    end

    private

    def parse_url(url)
      # Turn this into a valid URI before parsing
      uri = URI.parse(url.include?('://') ? url : "//#{url}")
      raise Temporalio::Error, 'Target host as URL with scheme are not supported' if uri.scheme

      # TODO: Add support for mTLS
      uri.scheme = 'http'
      uri.to_s
    end
  end
end
