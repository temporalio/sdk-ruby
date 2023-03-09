module Temporalio
  module Bridge
    class TlsOptions
      # Comment for server_root_ca_certificate attribute
      attr_reader :server_root_ca_cert

      # Comment for client_certificate attribute
      attr_reader :client_cert

      # Comment for client_certificate_key attribute
      attr_reader :client_cert_key

      # Comment for server_name_override attribute
      attr_reader :server_name_override

      def initialize(
        server_root_ca_cert:,
        client_cert:,
        client_cert_key:,
        server_name_override:
      )
        @server_root_ca_cert = server_root_ca_cert
        @client_cert = client_cert
        @client_cert_key = client_cert_key
        @server_name_override = server_name_override
      end
    end
  end
end
