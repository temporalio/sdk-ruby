# frozen_string_literal: true

require 'temporalio/internal/bridge'
require 'temporalio/temporalio_bridge'

module Temporalio
  module Internal
    module Bridge
      # @!visibility private
      class Client
        Options = Struct.new(
          :target_host,
          :client_name,
          :client_version,
          :rpc_metadata,
          :api_key, # Optional
          :identity,
          :tls, # Optional
          :rpc_retry,
          :keep_alive, # Optional
          :http_connect_proxy, # Optional
          keyword_init: true
        )

        # @!visibility private
        TLSOptions = Struct.new(
          :client_cert, # Optional
          :client_private_key, # Optional
          :server_root_ca_cert, # Optional
          :domain, # Optional
          keyword_init: true
        )

        # @!visibility private
        RPCRetryOptions = Struct.new(
          :initial_interval_ms,
          :randomization_factor,
          :multiplier,
          :max_interval_ms,
          :max_elapsed_time_ms, # Can use 0 for none
          :max_retries,
          keyword_init: true
        )

        # @!visibility private
        KeepAliveOptions = Struct.new(
          :interval_ms,
          :timeout_ms,
          keyword_init: true
        )

        # @!visibility private
        HTTPConnectProxyOptions = Struct.new(
          :target_host,
          :basic_auth_user, # Optional
          :basic_auth_pass, # Optional,
          keyword_init: true
        )

        # @!visibility private
        def self.new(runtime, options)
          Bridge.async_call do |queue|
            async_new(runtime, options) do |val|
              queue.push(val)
            end
          end
        end

        # @!visibility private
        def _invoke_rpc(
          service:,
          rpc:,
          request:,
          response_class:,
          rpc_retry:,
          rpc_metadata:,
          rpc_timeout_ms:
        )
          response_bytes = Bridge.async_call do |queue|
            async_invoke_rpc(
              service:,
              rpc:,
              request: request.to_proto,
              rpc_retry:,
              rpc_metadata:,
              rpc_timeout_ms:
            ) do |val|
              queue.push(val)
            end
          end
          response_class.decode(response_bytes)
        end
      end
    end
  end
end
