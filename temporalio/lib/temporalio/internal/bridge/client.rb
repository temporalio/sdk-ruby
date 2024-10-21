# frozen_string_literal: true

require 'temporalio/internal/bridge'

module Temporalio
  module Internal
    module Bridge
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

        TLSOptions = Struct.new(
          :client_cert, # Optional
          :client_private_key, # Optional
          :server_root_ca_cert, # Optional
          :domain, # Optional
          keyword_init: true
        )

        RPCRetryOptions = Struct.new(
          :initial_interval,
          :randomization_factor,
          :multiplier,
          :max_interval,
          :max_elapsed_time, # Can use 0 for none
          :max_retries,
          keyword_init: true
        )

        KeepAliveOptions = Struct.new(
          :interval,
          :timeout,
          keyword_init: true
        )

        HTTPConnectProxyOptions = Struct.new(
          :target_host,
          :basic_auth_user, # Optional
          :basic_auth_pass, # Optional,
          keyword_init: true
        )

        def self.new(runtime, options)
          queue = Queue.new
          async_new(runtime, options, queue)
          result = queue.pop
          raise result if result.is_a?(Exception)

          result
        end

        def _invoke_rpc(
          service:,
          rpc:,
          request:,
          response_class:,
          rpc_options:
        )
          # Build cancellation token if needed
          if rpc_options&.cancellation
            rpc_cancellation_token = CancellationToken.new
            rpc_options&.cancellation&.add_cancel_callback { rpc_cancellation_token.cancel }
          end

          queue = Queue.new
          async_invoke_rpc(
            service:,
            rpc:,
            request: request.to_proto,
            rpc_retry: rpc_options&.override_retry || false,
            rpc_metadata: rpc_options&.metadata,
            rpc_timeout: rpc_options&.timeout,
            rpc_cancellation_token:,
            queue:
          )
          result = queue.pop
          raise result if result.is_a?(Exception)

          response_class.decode(result)
        end
      end
    end
  end
end
