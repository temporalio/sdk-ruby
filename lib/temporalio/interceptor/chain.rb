module Temporalio
  module Interceptor
    # @api private
    class Chain
      def initialize(interceptors = [])
        @interceptors = interceptors
      end

      def invoke(method, input)
        chain = interceptors.dup

        traverse_chain = lambda do |i|
          if chain.empty?
            yield(i)
          else
            chain.shift.public_send(method, i, &traverse_chain)
          end
        end

        traverse_chain.call(input)
      end

      private

      attr_reader :interceptors
    end
  end
end
