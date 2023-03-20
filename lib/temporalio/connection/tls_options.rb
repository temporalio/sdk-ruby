module Temporalio
  class Connection
    class TlsOptions
      # Root CA certificate used by the server.
      # If not set, and the server's cert is issued by someone the operating system trusts,
      # verification will still work (ex: Cloud offering).
      attr_reader :server_root_ca_cert

      # Client certificate used to authenticate with the server.
      attr_reader :client_cert

      # Client private key used to authenticate with the server.
      attr_reader :client_private_key

      # Overrides the target name used for SSL host name checking. If this attribute is not specified, the name used for
      # SSL host name checking will be the host part of the connection target address. This _should_ be used for testing
      # only.
      attr_reader :server_name_override

      # @param [String] server_root_ca_cert Root CA certificate used by the server. If not set, and the server's
      #   cert is issued by someone the operating system trusts, verification will still work (ex: Cloud offering).
      # @param [String] client_cert
      # @param [String] client_private_key
      # @param [String] server_name_override
      def initialize(
        server_root_ca_cert: nil,
        client_cert: nil,
        client_private_key: nil,
        server_name_override: nil
      )
        @server_root_ca_cert = server_root_ca_cert
        @client_cert = client_cert
        @client_private_key = client_private_key
        @server_name_override = server_name_override
      end
    end
  end
end