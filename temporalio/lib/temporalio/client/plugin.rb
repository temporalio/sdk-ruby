# frozen_string_literal: true

module Temporalio
  class Client
    # Plugin mixin to include for configuring clients and/or intercepting connect calls.
    #
    # This is a low-level implementation that requires abstract methods herein to be implemented. Many implementers may
    # prefer {SimplePlugin} which includes this.
    #
    # WARNING: Plugins are experimental.
    module Plugin
      # @abstract
      # @return [String] Name of the plugin.
      def name
        raise NotImplementedError
      end

      # Configure a client.
      #
      # @abstract
      # @param options [Options] Current immutable options set.
      # @return [Options] Options to use, possibly updated from original.
      def configure_client(options)
        raise NotImplementedError
      end

      # Connect a client.
      #
      # Implementers are expected to delegate to next_call to perform the connection. Note, this does not apply to users
      # explicitly creating connections via {Connection} constructor.
      #
      # @abstract
      # @param options [Connection::Options] Current immutable options set.
      # @param next_call [Proc] Proc for the next plugin in the chain to call. It accepts the options and returns a
      #   {Connection}.
      # @return [Connection] Connected connection.
      def connect_client(options, next_call)
        raise NotImplementedError
      end
    end
  end
end
