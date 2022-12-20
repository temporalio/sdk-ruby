module Temporalio
  module Bridge
    # @api private
    class Error < StandardError
      class WorkerShutdown < Error; end
    end
  end
end
