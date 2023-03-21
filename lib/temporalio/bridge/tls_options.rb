module Temporalio
  module Bridge
    class TlsOptions
      attr_reader :server_root_ca_cert, :client_cert, :client_private_key, :server_name_override

      def initialize(
        server_root_ca_cert:,
        client_cert:,
        client_private_key:,
        server_name_override:
      )
        @server_root_ca_cert = server_root_ca_cert
        @client_cert = client_cert
        @client_private_key = client_private_key
        @server_name_override = server_name_override
      end
    end
  end
end
