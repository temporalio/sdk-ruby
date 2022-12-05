module Temporal
  class Activity
    class Context
      attr_reader :info

      def initialize(info)
        @thread = Thread.current
        @info = info
      end

      private

      attr_reader :thread
    end
  end
end
