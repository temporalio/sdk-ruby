module Temporalio
  module Bridge
    class ConnectOptions
      # Comment for url attribute
      attr_reader :url

      # Comment for tls attribute
      attr_reader :tls

      # Comment for identity attribute
      attr_reader :identity

      # Comment for client_version attribute
      attr_reader :client_version

      # Comment for metadata attribute
      attr_reader :metadata

      # Comment for retry_config attribute
      attr_reader :retry_config

      def initialize(url:, tls:, identity:, client_version:, metadata:, retry_config:)
        @url = url
        @tls = tls
        @identity = identity
        @metadata = metadata
        @retry_config = retry_config
        @client_version = client_version
      end
    end
  end
end
