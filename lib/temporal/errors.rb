module Temporal
  # Superclass for all Temporal errors
  class Error < StandardError
    # Superclass for RPC and proto related errors
    class RPCError < Error; end
    class UnexpectedResponse < RPCError; end
  end
end
