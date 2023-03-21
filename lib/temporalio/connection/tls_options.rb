module Temporalio
  class Connection
    class TlsOptions
      # Root CA certificate used by the server. If not set, the server's certificate will be
      # validated against the operating system's root certificates.
      #
      # Leave unset for Temporal Cloud.
      attr_reader :server_root_ca_cert

      # Client certificate used to authenticate with the server. If set, a corresponding
      # `client_private_key` must be provided.
      #
      # @default do not use client side authentication.
      attr_reader :client_cert

      # Client private key used to authenticate with the server. Required if `client_cert` is set.
      attr_reader :client_private_key

      # Overrides the target name used for validation of the server SSL certificate. If not
      # specified, the server certificate will be checked against the host part of the connection
      # target address. This _should_ be used for testing only.
      #
      # Leave unset for Temporal Cloud.
      #
      # @default Validate the server certificate against the host part of the connection target address.
      attr_reader :server_name_override

      # @param [String?] server_root_ca_cert Root CA certificate used by the server.
      # @param [String?] client_cert Client certificate used to authenticate with the server.
      # @param [String?] client_private_key Client private key used to authenticate with the server.
      # @param [String?] server_name_override Overrides the target name used for validation of the
      #                  server SSL certificate.
      # @raise [ArgumentError] if `client_cert` and `client_private_key` are not both set or both unset
      def initialize(
        server_root_ca_cert: nil,
        client_cert: nil,
        client_private_key: nil,
        server_name_override: nil
      )
        if (client_cert && !client_private_key) || (!client_cert && client_private_key)
          raise ArgumentError, 'client_cert and client_private_key must be either both set or both unset'
        end

        @server_root_ca_cert = server_root_ca_cert
        @client_cert = client_cert
        @client_private_key = client_private_key
        @server_name_override = server_name_override
      end
    end
  end
end
