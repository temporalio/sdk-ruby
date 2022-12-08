module Temporal
  class Activity
    class Context
      attr_reader :info

      def initialize(info, heartbeat_proc)
        @thread = Thread.current
        @info = info
        @heartbeat_proc = heartbeat_proc
      end

      def heartbeat(*details)
        heartbeat_proc.call(*details)
      end

      private

      attr_reader :thread, :heartbeat_proc
    end
  end
end
