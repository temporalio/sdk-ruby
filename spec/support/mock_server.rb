require 'grpc'

class MockServer
  # @param service [GRPC::GenericService]
  # @return [Array<GRPC::RpcServer, String>] server and address
  def self.start_mock_server(service)
    server = GRPC::RpcServer.new # (pool_size: 10)
    port = server.add_http2_port('127.0.0.1:0', :this_port_is_insecure)
    server.handle(service)

    Thread.new do
      server.run
    end
    server.wait_till_running

    return [server, "127.0.0.1:#{port}"]
  end

  # @param service [GRPC::GenericService]
  def self.with_mock_server(service)
    server, address = start_mock_server(service)
    yield address
    server.stop
  end
end
