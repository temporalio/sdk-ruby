# frozen_string_literal: true

module Temporalio
  class Client
    # Base class for providing metadata (headers) to gRPC requests
    class MetadataProvider
      def metadata
        raise NotImplementedError, 'Subclasses must implement metadata method'
      end
    end

    # Simple JWT token provider
    class JwtTokenProvider < MetadataProvider
      def initialize(token)
        @token = token
      end

      def metadata
        { 'authorization' => "Bearer #{@token}" }
      end
    end

    # JWT supplier provider (calls lambda for token)
    class JwtTokenSupplierProvider < MetadataProvider
      def initialize(supplier)
        @supplier = supplier
      end

      def metadata
        token = @supplier.call
        token ? { 'authorization' => "Bearer #{token}" } : {}
      end
    end

    # Keycloak integration
    class KeycloakJwtProvider < MetadataProvider
      require 'net/http'
      require 'json'

      def initialize(keycloak_url, realm, client_id, client_secret, cache_duration: 3600)
        @keycloak_url = keycloak_url
        @realm = realm
        @client_id = client_id
        @client_secret = client_secret
        @cache_duration = cache_duration
        @cached_token = nil
        @token_expiry = nil
        @mutex = Mutex.new
      end

      def metadata
        token = ensure_token
        token ? { 'authorization' => "Bearer #{token}" } : {}
      end

      private

      def ensure_token
        @mutex.synchronize do
          fetch_new_token if @cached_token.nil? || token_expired?
          @cached_token
        end
      end

      def token_expired?
        @token_expiry.nil? || Time.now > @token_expiry
      end

      def fetch_new_token
        token_url = "#{@keycloak_url}/realms/#{@realm}/protocol/openid-connect/token"
        uri = URI(token_url)

        request = Net::HTTP::Post.new(uri.path)
        request['Content-Type'] = 'application/x-www-form-urlencoded'
        request.set_form_data(
          grant_type: 'client_credentials',
          client_id: @client_id,
          client_secret: @client_secret
        )

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        response = http.request(request)

        if response.is_a?(Net::HTTPSuccess)
          body = JSON.parse(response.body)
          @cached_token = body['access_token']
          @token_expiry = Time.now + body['expires_in'] - 60
        else
          raise "Keycloak token fetch failed: #{response.code}"
        end
      end
    end
  end
end
