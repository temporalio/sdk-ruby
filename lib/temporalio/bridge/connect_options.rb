module Temporalio
  module Bridge
    class ConnectOptions
      attr_reader :url, :tls, :identity, :client_version, :metadata, :retry_config

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
