# frozen_string_literal: true

require 'pathname'
require 'temporalio/internal/bridge'

module Temporalio
  # Environment and file-based configuration for Temporal clients
  module EnvConfig
    # This module provides utilities to load Temporal client configuration from TOML files
    # and environment variables.
    #
    # DataSource types:
    # - Pathname: Path to a configuration file
    # - String: TOML configuration content
    # - nil: No configuration source

    # Convert a data source to path and data parameters for the bridge
    # @param source [Pathname, String, nil] Configuration source
    # @return [Array<String?, Array<Integer>?>] Tuple of [path, data_bytes]
    def self.source_to_path_and_data(source)
      case source
      when Pathname
        [source.to_s, nil]
      when String
        [nil, source.encode('UTF-8').bytes]
      when nil
        [nil, nil]
      else
        raise TypeError, "Must be Pathname, String, or nil, got #{source.class}"
      end
    end

    # TLS configuration as specified as part of client configuration
    #
    # @!attribute [r] disabled
    #   @return [Boolean] If true, TLS is explicitly disabled
    # @!attribute [r] server_name
    #   @return [String, nil] SNI override
    # @!attribute [r] server_root_ca_cert
    #   @return [Pathname, String, nil] Server CA certificate source
    # @!attribute [r] client_cert
    #   @return [Pathname, String, nil] Client certificate source
    # @!attribute [r] client_private_key
    #   @return [Pathname, String, nil] Client key source
    ClientConfigTLS = Data.define(:disabled, :server_name, :server_root_ca_cert, :client_cert, :client_private_key)

    class ClientConfigTLS
      # Set default values
      def initialize(disabled: false, server_name: nil, server_root_ca_cert: nil, client_cert: nil, client_private_key: nil)
        super
      end

      # Create a ClientConfigTLS from a hash
      # @param hash [Hash, nil] Hash representation
      # @return [ClientConfigTLS, nil] The TLS configuration or nil if hash is nil/empty
      def self.from_h(hash)
        return nil if hash.nil? || hash.empty?

        new(
          disabled: hash[:disabled] || hash['disabled'] || false,
          server_name: hash[:server_name] || hash['server_name'],
          server_root_ca_cert: hash_to_source(hash[:server_ca_cert] || hash['server_ca_cert']),
          client_cert: hash_to_source(hash[:client_cert] || hash['client_cert']),
          client_private_key: hash_to_source(hash[:client_key] || hash['client_key'])
        )
      end

      # Convert a hash representation to a data source
      # @param hash [Hash, nil] Hash with :path or :data key
      # @return [Pathname, String, nil] Data source
      def self.hash_to_source(hash)
        return nil if hash.nil?

        # Always expect a hash with path or data
        if hash[:path] || hash['path']
          # Return path as string to match old behavior
          hash[:path] || hash['path']
        elsif hash[:data] || hash['data']
          hash[:data] || hash['data']
        end
      end

      # Convert to a hash that can be used for TOML serialization
      # @return [Hash] Dictionary representation
      def to_h
        {
          disabled: disabled ? disabled : nil,
          server_name: server_name,
          server_ca_cert: server_root_ca_cert ? source_to_hash(server_root_ca_cert) : nil,
          client_cert: client_cert ? source_to_hash(client_cert) : nil,
          client_key: client_private_key ? source_to_hash(client_private_key) : nil
        }.compact
      end

      # Create a TLS configuration for use with connections
      # @return [Connection::TLSOptions, false] TLS options or false if disabled
      def to_tls_options
        return false if disabled

        Temporalio::Client::Connection::TLSOptions.new(
          domain: server_name,
          server_root_ca_cert: read_source(server_root_ca_cert),
          client_cert: read_source(client_cert),
          client_private_key: read_source(client_private_key)
        )
      end

      private

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
          # If it's a string path (from TOML), read the file
          # Otherwise return as content
          if File.exist?(source)
            File.read(source)
          else
            source
          end
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
    # See #to_client_connect_config to transform the profile to a connect config hash.
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

    class ClientConfigProfile
      # Create a ClientConfigProfile instance with defaults
      def initialize(address: nil, namespace: nil, api_key: nil, tls: nil, grpc_meta: {})
        super
      end

      # Create a ClientConfigProfile from a hash
      # @param hash [Hash] Hash representation
      # @return [ClientConfigProfile] The client profile
      def self.from_h(hash)
        new(
          address: hash[:address] || hash['address'],
          namespace: hash[:namespace] || hash['namespace'],
          api_key: hash[:api_key] || hash['api_key'],
          tls: ClientConfigTLS.from_h(hash[:tls] || hash['tls']),
          grpc_meta: hash[:grpc_meta] || hash['grpc_meta'] || {}
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
        path, data = EnvConfig.source_to_path_and_data(config_source)

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


      # Convert to a hash that can be used for TOML serialization
      # @return [Hash] Dictionary representation
      def to_h
        {
          address: address,
          namespace: namespace,
          api_key: api_key,
          tls: tls&.to_h&.then { |tls_hash| tls_hash.empty? ? nil : tls_hash }, # steep:ignore
          grpc_meta: grpc_meta&.empty? ? nil : grpc_meta
        }.compact
      end

      # Create a client connect config from this profile
      # @return [Hash] Arguments that can be passed to Client.connect
      def to_client_connect_config
        {
          target_host: address,
          namespace: namespace,
          api_key: api_key,
          tls: tls&.to_tls_options,
          rpc_metadata: (grpc_meta if grpc_meta && !grpc_meta.empty?)
        }.compact
      end
    end

    # Client configuration loaded from TOML and environment variables.
    #
    # This contains a mapping of profile names to client profiles.
    #
    # @!attribute [r] profiles
    #   @return [Hash<String, ClientConfigProfile>] Map of profile name to its corresponding ClientConfigProfile
    ClientConfig = Data.define(:profiles)

    class ClientConfig
      # Create a ClientConfig instance with defaults
      def initialize(profiles: {})
        super
      end

      # Create a ClientConfig from a hash
      # @param hash [Hash] Hash representation
      # @return [ClientConfig] The client configuration
      def self.from_h(hash)
        profiles = hash.transform_values do |profile_hash|
          ClientConfigProfile.from_h(profile_hash)
        end
        new(profiles)
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
        path, data = Temporalio::EnvConfig.source_to_path_and_data(config_source)

        loaded_profiles = Temporalio::Internal::Bridge::EnvConfig.load_client_config(
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
      # @return [Hash] Hash of keyword arguments for Client.connect
      def self.load_client_connect_config(
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
        prof.to_client_connect_config
      end

      # Convert to a hash that can be used for TOML serialization
      # @return [Hash] Dictionary representation
      def to_h
        profiles.transform_values(&:to_h)
      end
    end
  end
end
