module Temporalio
  module Bridge
    class Error < StandardError
      class WorkerShutdown < Error; end
    end
  end
end
