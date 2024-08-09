# frozen_string_literal: true

require 'socket'
require 'temporalio/client/connection/cloud_service'
require 'temporalio/client/connection/operator_service'
require 'temporalio/client/connection/workflow_service'
require 'temporalio/internal/bridge/client'
require 'temporalio/runtime'
require 'temporalio/version'

module Temporalio
  class Client
    # Connection to Temporal server that is not namespace specific. Most users will use {Client.connect} instead of this
    # directly.
    class Connection
      # Options as returned from {dup_options} for +**to_h+ splat use in {initialize}. See {initialize} for details.
      Options = Struct.new(
        :target_host,
        :api_key,
        :tls,
        :rpc_metadata,
        :rpc_retry,
        :identity,
        :keep_alive,
        :http_connect_proxy,
        :runtime,
        :lazy_connect,
        keyword_init: true
      )

      # TLS options. All attributes are optional, and an empty options set just enables default TLS.
      #
      # @!attribute client_cert
      #   @return [String, nil] Client certificate for mTLS. Must be combined with {client_private_key}.
      # @!attribute client_private_key
      #   @return [String, nil] Client private key for mTLS. Must be combined with {client_cert}.
      # @!attribute server_root_ca_cert
      #   @return [String, nil] Root CA certificate to validate the server certificate against. This is only needed for
      #     self-hosted servers with self-signed server certificates.
      # @!attribute domain
      #   @return [String, nil] SNI override. This is only needed for self-hosted servers with certificates that do not
      #     match the hostname being connected to.
      TLSOptions = Struct.new(
        :client_cert,
        :client_private_key,
        :server_root_ca_cert,
        :domain,
        keyword_init: true
      )

      # Retry options for server calls when retry is enabled (which it is by default on all high-level {Client} calls).
      # For most users, the default is preferred.
      #
      # @!attribute initial_interval
      #   @return [Float] Initial backoff interval, default 0.1.
      # @!attribute randomization_factor
      #   @return [Float] Randomization jitter to add, default 0.2.
      # @!attribute multiplier
      #   @return [Float] Backoff multiplier, default 1.5.
      # @!attribute max_interval
      #   @return [Float] Maximum backoff interval, default 5.0.
      # @!attribute max_elapsed_time
      #   @return [Float] Maximum total time, default 10.0. Can use 0 for no max.
      # @!attribute max_retries
      #   @return [Integer] Maximum number of retries, default 10.
      RPCRetryOptions = Struct.new(
        :initial_interval,
        :randomization_factor,
        :multiplier,
        :max_interval,
        :max_elapsed_time,
        :max_retries,
        keyword_init: true
      ) do
        def initialize(*, **kwargs)
          kwargs[:initial_interval] = 0.1 unless kwargs.key?(:initial_interval)
          kwargs[:randomization_factor] = 0.2 unless kwargs.key?(:randomization_factor)
          kwargs[:multiplier] = 1.5 unless kwargs.key?(:multiplier)
          kwargs[:max_interval] = 5.0 unless kwargs.key?(:max_interval)
          kwargs[:max_elapsed_time] = 10.0 unless kwargs.key?(:max_elapsed_time)
          kwargs[:max_retries] = 10 unless kwargs.key?(:max_retries)
          super
        end
      end

      # Keep-alive options for client connections. For most users, the default is preferred.
      #
      # @!attribute interval
      #   @return [Float] Interval to send HTTP2 keep alive pings, default 30.0.
      # @!attribute timeout
      #   @return [Float] Timeout that the keep alive must be responded to within or the connection will be closed,
      #     default 15.0.
      KeepAliveOptions = Struct.new(
        :interval,
        :timeout,
        keyword_init: true
      ) do
        def initialize(*, **kwargs)
          kwargs[:interval] = 30.0 unless kwargs.key?(:interval)
          kwargs[:timeout] = 15.0 unless kwargs.key?(:timeout)
          super
        end
      end

      # Options for HTTP CONNECT proxy for client connections.
      #
      # @!attribute target_host
      #   @return [String] Target host:port for the HTTP CONNECT proxy.
      # @!attribute basic_auth_user
      #   @return [String, nil] User for HTTP basic auth for the proxy, must be combined with {basic_auth_pass}.
      # @!attribute basic_auth_pass
      #   @return [String, nil] Pass for HTTP basic auth for the proxy, must be combined with {basic_auth_user}.
      HTTPConnectProxyOptions = Struct.new(
        :target_host,
        :basic_auth_user, # Optional
        :basic_auth_pass, # Optional,
        keyword_init: true
      )

      # @return [String] Client identity.
      attr_reader :identity

      # @return [WorkflowService] Raw gRPC workflow service.
      attr_reader :workflow_service

      # @return [OperatorService] Raw gRPC operator service.
      attr_reader :operator_service

      # @return [CloudService] Raw gRPC cloud service.
      attr_reader :cloud_service

      # Connect to Temporal server. Most users will use {Client.connect} instead of this directly. Parameters here match
      # {Options} returned from {dup_options} by intention so options can be altered and splatted to create a new
      # connection.
      #
      # @param target_host [String] +host:port+ for the Temporal server. For local development, this is often
      #   +localhost:7233+.
      # @param api_key [String, nil] API key for Temporal. This becomes the +Authorization+ HTTP header with +"Bearer "+
      #   prepended. This is only set if RPC metadata doesn't already have an +authorization+ key.
      # @param tls [Boolean, TLSOptions] If false, do not use TLS. If true, use system default TLS options. If TLS
      #   options are present, those TLS options will be used.
      # @param rpc_metadata [Hash<String, String>] Headers to use for all calls to the server. Keys here can be
      #   overriden by per-call RPC metadata keys.
      # @param rpc_retry [RPCRetryOptions] Retry options for direct service calls (when opted in) or all high-level
      #   calls made by this client (which all opt-in to retries by default).
      # @param identity [String] Identity for this client.
      # @param keep_alive [KeepAliveOptions] Keep-alive options for the client connection. Can be set to +nil+ to
      #   disable.
      # @param http_connect_proxy [HTTPConnectProxyOptions] Options for HTTP CONNECT proxy.
      # @param runtime [Runtime] Runtime for this client.
      # @param lazy_connect [Boolean] If true, there is no connection until the first call is attempted or a worker
      #   is created with it. Clients from lazy connections cannot be used for workers if they have not performed a
      #   connection.
      #
      # @see Client.connect
      def initialize(
        target_host:,
        api_key: nil,
        tls: false,
        rpc_metadata: {},
        rpc_retry: RPCRetryOptions.new,
        identity: "#{Process.pid}@#{Socket.gethostname}",
        keep_alive: KeepAliveOptions.new,
        http_connect_proxy: nil,
        runtime: Runtime.default,
        lazy_connect: false
      )
        @options = Options.new(
          target_host:,
          api_key:,
          tls:,
          rpc_metadata:,
          rpc_retry:,
          identity:,
          keep_alive:,
          http_connect_proxy:,
          runtime:,
          lazy_connect:
        )
        # Create core client now if not lazy
        _core_client unless lazy_connect
        # Create service instances
        @workflow_service = WorkflowService.new(self)
        @operator_service = OperatorService.new(self)
        @cloud_service = CloudService.new(self)
      end

      # @return [String] Target host this connection is connected to.
      def target_host
        @options.target_host
      end

      # @return [Options] Shallow duplication of options for potential use in {initialize}. Note, this is shallow, so
      #   attributes like {Options.rpc_metadata} are not duplicated, but no mutations will apply.
      def dup_options
        @options.dup
      end

      # @return [Boolean] Whether this connection is connected. This is always `true` unless `lazy_connect` option was
      #   originally set, in which case this will be `false` until the first call is made.
      def connected?
        !@core_client.nil?
      end

      # @!visibility private
      def _core_client
        # If lazy, this needs to be done under mutex
        if @options.lazy_connect
          @core_client_mutex ||= Mutex.new
          @core_client_mutex.synchronize do
            @core_client ||= new_core_client
          end
        else
          @core_client ||= new_core_client
        end
      end

      private

      def new_core_client
        options = Internal::Bridge::Client::Options.new(
          target_host: @options.target_host,
          client_name: 'temporal-ruby',
          client_version: VERSION,
          rpc_metadata: @options.rpc_metadata,
          api_key: @options.api_key,
          rpc_retry: Internal::Bridge::Client::RPCRetryOptions.new(
            initial_interval: @options.rpc_retry.initial_interval,
            randomization_factor: @options.rpc_retry.randomization_factor,
            multiplier: @options.rpc_retry.multiplier,
            max_interval: @options.rpc_retry.max_interval,
            max_elapsed_time: @options.rpc_retry.max_elapsed_time,
            max_retries: @options.rpc_retry.max_retries
          ),
          identity: @options.identity || "#{Process.pid}@#{Socket.gethostname}"
        )
        if @options.tls
          options.tls = if @options.tls.is_a?(TLSOptions)
                          Internal::Bridge::Client::TLSOptions.new(
                            client_cert: @options.tls.client_cert,
                            client_private_key: @options.tls.client_private_key,
                            server_root_ca_cert: @options.tls.server_root_ca_cert,
                            domain: @options.tls.domain
                          )
                        else
                          Internal::Bridge::Client::TLSOptions.new
                        end
        end
        if @options.keep_alive
          options.keep_alive = Internal::Bridge::Client::KeepAliveOptions.new(
            interval: @options.keep_alive.interval,
            timeout: @options.keep_alive.timeout
          )
        end
        if @options.http_connect_proxy
          options.http_connect_proxy = Internal::Bridge::Client::HTTPConnectProxyOptions.new(
            target_host: @options.http_connect_proxy.target_host,
            basic_auth_user: @options.http_connect_proxy.basic_auth_user,
            basic_auth_pass: @options.http_connect_proxy.basic_auth_pass
          )
        end
        Internal::Bridge::Client.new(@options.runtime._core_runtime, options)
      end
    end
  end
end
