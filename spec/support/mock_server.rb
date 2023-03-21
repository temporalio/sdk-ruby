if __FILE__ == $PROGRAM_NAME
  $LOAD_PATH << File.expand_path('..', File.dirname(__FILE__))
  $LOAD_PATH << File.expand_path('../../lib/gen', File.dirname(__FILE__))
end

require 'grpc'
require 'support/grpc/temporal/api/testservice/v1/service_services_pb'
require 'support/grpc/temporal/api/workflowservice/v1/service_services_pb'

class MockTestService < Temporalio::Api::TestService::V1::TestService::Service
  # Automatically add handling for each RPC method returning an empty response
  rpc_descs.each do |rpc, desc|
    define_method(::GRPC::GenericService.underscore(rpc.to_s)) do |_request, _call|
      desc.output.new # return an empty response
    end
  end
end

class MockWorkflowService < Temporalio::Api::WorkflowService::V1::WorkflowService::Service
  # Automatically add handling for each RPC method returning an empty response
  rpc_descs.each do |rpc, desc|
    define_method(::GRPC::GenericService.underscore(rpc.to_s)) do |_request, _call|
      desc.output.new # return an empty response
    end
  end
end

class MockServer
  def self.run(address)
    server = GRPC::RpcServer.new
    server.add_http2_port(address, :this_port_is_insecure)
    server.handle(MockTestService.new)
    server.handle(MockWorkflowService.new)
    server.run_till_terminated_or_interrupted([1, 'int', 'SIGQUIT'])
  end

  # @param service [GRPC::GenericService]
  def self.with_mock_server(service)
    server = GRPC::RpcServer.new
    port = server.add_http2_port('localhost:0', :this_port_is_insecure)
    server.handle(service)

    Thread.new do
      server.run
    end
    server.wait_till_running

    yield "localhost:#{port}"

    server.stop
    server.wait_till_stopped
  end
end

if __FILE__ == $PROGRAM_NAME
  MockServer.run('0.0.0.0:4444')
end
