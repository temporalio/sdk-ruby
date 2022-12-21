if __FILE__ == $PROGRAM_NAME
  $LOAD_PATH << File.expand_path('..', File.dirname(__FILE__))
  $LOAD_PATH << File.expand_path('../../lib/gen', File.dirname(__FILE__))
end

require 'grpc'
require 'support/grpc/temporal/api/workflowservice/v1/service_services_pb'

class MockServer < Temporalio::Api::WorkflowService::V1::WorkflowService::Service
  def self.run(address)
    server = GRPC::RpcServer.new
    server.add_http2_port(address, :this_port_is_insecure)
    server.handle(new)
    server.run_till_terminated_or_interrupted([1, 'int', 'SIGQUIT'])
  end

  # Automatically add handling for each RPC method returning an empty response
  rpc_descs.each do |rpc, desc|
    define_method(::GRPC::GenericService.underscore(rpc.to_s)) do |_request, _call|
      desc.output.new # return an empty response
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  MockServer.run('0.0.0.0:4444')
end
