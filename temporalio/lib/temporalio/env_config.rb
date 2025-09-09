# frozen_string_literal: true

require 'pathname'
require 'temporalio/internal/bridge'

module Temporalio
  # Environment and file-based configuration for Temporal clients
  module EnvConfig
    # This module provides utilities to load Temporal client configuration from TOML files
    # and environment variables.

    # TLS configuration as specified as part of client configuration
    #
    # @!attribute [r] disabled
    #   @return [Boolean, nil] If true, TLS is explicitly disabled; if nil, not specified
    # @!attribute [r] server_name
    #   @return [String, nil] SNI override
    # @!attribute [r] server_root_ca_cert
    #   @return [Pathname, String, nil] Server CA certificate source
    # @!attribute [r] client_cert
    #   @return [Pathname, String, nil] Client certificate source
    # @!attribute [r] client_private_key
    #   @return [Pathname, String, nil] Client key source
    ClientConfigTLS = Data.define(:disabled, :server_name, :server_root_ca_cert, :client_cert, :client_private_key)

    # TLS configuration for Temporal client connections.
    #
    # This class provides methods for creating, serializing, and converting
    # TLS configuration objects used by Temporal clients.
    class ClientConfigTLS
      # Create a ClientConfigTLS from a hash
      # @param hash [Hash, nil] Hash representation
      # @return [ClientConfigTLS, nil] The TLS configuration or nil if hash is nil/empty
      def self.from_h(hash)
        return nil if hash.nil? || hash.empty?

        new(
          disabled: hash[:disabled],
          server_name: hash[:server_name],
          server_root_ca_cert: hash_to_source(hash[:server_ca_cert]),
          client_cert: hash_to_source(hash[:client_cert]),
          client_private_key: hash_to_source(hash[:client_key])
        )
      end

      # Set default values
      def initialize(disabled: nil, server_name: nil, server_root_ca_cert: nil, client_cert: nil,
                     client_private_key: nil)
        super
      end

      # Convert to a hash that can be used for TOML serialization
      # @return [Hash] Dictionary representation
      def to_h
        {
          disabled:,
          server_name:,
          server_ca_cert: server_root_ca_cert ? source_to_hash(server_root_ca_cert) : nil,
          client_cert: client_cert ? source_to_hash(client_cert) : nil,
          client_key: client_private_key ? source_to_hash(client_private_key) : nil
        }.compact
      end

      # Create a TLS configuration for use with connections
      # @return [Connection::TLSOptions, false] TLS options or false if disabled
      def to_client_tls_options
        return false if disabled

        Client::Connection::TLSOptions.new(
          domain: server_name,
          server_root_ca_cert: read_source(server_root_ca_cert),
          client_cert: read_source(client_cert),
          client_private_key: read_source(client_private_key)
        )
      end

      private

      class << self
        private

        # Convert hash to source object (Pathname or String)
        def hash_to_source(hash)
          return nil if hash.nil?

          # Always expect a hash with path or data
          if hash[:path]
            Pathname.new(hash[:path])
          elsif hash[:data]
            hash[:data]
          end
        end
      end

      def source_to_hash(source)
        case source
        when Pathname
          { path: source.to_s }
        when String
          # String is always treated as data content
          { data: source }
        when nil
          nil
        else
          raise TypeError, "Source must be Pathname, String, or nil, got #{source.class}"
        end
      end

      def read_source(source)
        case source
        when Pathname
          File.read(source.to_s)
        when String
          # String is always treated as raw data content
          source
        when nil
          nil
        else
          raise TypeError, "Source must be Pathname, String, or nil, got #{source.class}"
        end
      end
    end

    # Represents a client configuration profile.
    #
    # This class holds the configuration as loaded from a file or environment.
    # See #to_client_connect_options to transform the profile to a connect config hash.
    #
    # @!attribute [r] address
    #   @return [String, nil] Client address
    # @!attribute [r] namespace
    #   @return [String, nil] Client namespace
    # @!attribute [r] api_key
    #   @return [String, nil] Client API key
    # @!attribute [r] tls
    #   @return [ClientConfigTLS, nil] TLS configuration
    # @!attribute [r] grpc_meta
    #   @return [Hash] gRPC metadata
    ClientConfigProfile = Data.define(:address, :namespace, :api_key, :tls, :grpc_meta)

    # A client configuration profile loaded from environment and files.
    #
    # This class represents a complete client configuration profile that can be
    # loaded from TOML files and environment variables, and converted to client
    # connection options.
    class ClientConfigProfile
      # Create a ClientConfigProfile from a hash
      # @param hash [Hash] Hash representation
      # @return [ClientConfigProfile] The client profile
      def self.from_h(hash)
        new(
          address: hash[:address],
          namespace: hash[:namespace],
          api_key: hash[:api_key],
          tls: ClientConfigTLS.from_h(hash[:tls]),
          grpc_meta: hash[:grpc_meta] || {}
        )
      end

      # Load a single client profile from given sources, applying env overrides.
      #
      # @param profile [String, nil] Profile to load from the config
      # @param config_source [Pathname, String, nil] Configuration source -
      #   Pathname for file path, String for TOML content
      # @param disable_file [Boolean] If true, file loading is disabled
      # @param disable_env [Boolean] If true, environment variable loading and overriding is disabled
      # @param config_file_strict [Boolean] If true, will error on unrecognized keys
      # @param override_env_vars [Hash, nil] Environment variables to use for loading and overrides
      # @return [ClientConfigProfile] The client configuration profile
      def self.load(
        profile: nil,
        config_source: nil,
        disable_file: false,
        disable_env: false,
        config_file_strict: false,
        override_env_vars: nil
      )
        path, data = EnvConfig._source_to_path_and_data(config_source)

        raw_profile = Internal::Bridge::EnvConfig.load_client_connect_config(
          profile,
          path,
          data,
          disable_file,
          disable_env,
          config_file_strict,
          override_env_vars || {}
        )

        from_h(raw_profile)
      end

      # Create a ClientConfigProfile instance with defaults
      def initialize(address: nil, namespace: nil, api_key: nil, tls: nil, grpc_meta: {})
        super
      end

      # Convert to a hash that can be used for TOML serialization
      # @return [Hash] Dictionary representation
      def to_h
        {
          address: address,
          namespace: namespace,
          api_key: api_key,
          tls: tls&.to_h&.then { |tls_hash| tls_hash.empty? ? nil : tls_hash }, # steep:ignore
          grpc_meta: grpc_meta && grpc_meta.empty? ? nil : grpc_meta
        }.compact
      end

      # Create a client connect config from this profile
      # @return [Array] Tuple of [positional_args, keyword_args] that can be splatted to Client.connect
      def to_client_connect_options
        positional_args = [address, namespace].compact
        keyword_args = {
          api_key: api_key,
          tls: tls&.to_client_tls_options,
          rpc_metadata: (grpc_meta if grpc_meta && !grpc_meta.empty?)
        }.compact

        [positional_args, keyword_args]
      end
    end

    # Client configuration loaded from TOML and environment variables.
    #
    # This contains a mapping of profile names to client profiles.
    #
    # @!attribute [r] profiles
    #   @return [Hash<String, ClientConfigProfile>] Map of profile name to its corresponding ClientConfigProfile
    ClientConfig = Data.define(:profiles)

    # Container for multiple client configuration profiles.
    #
    # This class holds a collection of named client profiles loaded from
    # configuration sources and provides methods for profile management
    # and client connection configuration.
    class ClientConfig
      # Create a ClientConfig from a hash
      # @param hash [Hash] Hash representation
      # @return [ClientConfig] The client configuration
      def self.from_h(hash)
        profiles = hash.transform_values do |profile_hash|
          ClientConfigProfile.from_h(profile_hash)
        end
        new(profiles: profiles)
      end

      # Load all client profiles from given sources.
      #
      # This does not apply environment variable overrides to the profiles, it
      # only uses an environment variable to find the default config file path
      # (TEMPORAL_CONFIG_FILE).
      #
      # @param config_source [Pathname, String, nil] Configuration source
      # @param disable_file [Boolean] If true, file loading is disabled
      # @param config_file_strict [Boolean] If true, will error on unrecognized keys
      # @param override_env_vars [Hash, nil] Environment variables to use
      # @return [ClientConfig] The client configuration
      def self.load(
        config_source: nil,
        disable_file: false,
        config_file_strict: false,
        override_env_vars: nil
      )
        path, data = EnvConfig._source_to_path_and_data(config_source)

        loaded_profiles = Internal::Bridge::EnvConfig.load_client_config(
          path,
          data,
          disable_file,
          config_file_strict,
          override_env_vars || {}
        )

        from_h(loaded_profiles)
      end

      # Load a single client profile and convert to connect config
      #
      # This is a convenience function that combines loading a profile and
      # converting it to a connect config hash.
      #
      # @param profile [String, nil] The profile to load from the config
      # @param config_source [Pathname, String, nil] Configuration source
      # @param disable_file [Boolean] If true, file loading is disabled
      # @param disable_env [Boolean] If true, environment variable loading and overriding is disabled
      # @param config_file_strict [Boolean] If true, will error on unrecognized keys
      # @param override_env_vars [Hash, nil] Environment variables to use for loading and overrides
      # @return [Array] Tuple of [positional_args, keyword_args] that can be splatted to Client.connect
      def self.load_client_connect_options(
        profile: nil,
        config_source: nil,
        disable_file: false,
        disable_env: false,
        config_file_strict: false,
        override_env_vars: nil
      )
        prof = ClientConfigProfile.load(
          profile: profile,
          config_source: config_source,
          disable_file: disable_file,
          disable_env: disable_env,
          config_file_strict: config_file_strict,
          override_env_vars: override_env_vars
        )
        prof.to_client_connect_options
      end

      # Create a ClientConfig instance with defaults
      def initialize(profiles: {})
        super
      end

      # Convert to a hash that can be used for TOML serialization
      # @return [Hash] Dictionary representation
      def to_h
        profiles.transform_values(&:to_h)
      end
    end

    # @param source [Pathname, String, nil] Configuration source
    # @return [Array<String?, String?>] Tuple of [path, data]
    # @!visibility private
    def self._source_to_path_and_data(source)
      case source
      when Pathname
        [source.to_s, nil]
      when String
        [nil, source]
      when nil
        [nil, nil]
      else
        raise TypeError, "Must be Pathname, String, or nil, got #{source.class}"
      end
    end
  end
end
