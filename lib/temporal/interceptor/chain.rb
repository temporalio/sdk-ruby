module Temporal
  module Interceptor
    class Chain
      def initialize(interceptors = [])
        @interceptors = interceptors
      end

      def invoke(method, input)
        chain = interceptors.dup

        traverse_chain = lambda do |input|
          if chain.empty?
            yield(input)
          else
            chain.shift.public_send(method, input, &traverse_chain)
          end
        end

        traverse_chain.call(input)
      end

      private

      attr_reader :interceptors
    end
  end
end
