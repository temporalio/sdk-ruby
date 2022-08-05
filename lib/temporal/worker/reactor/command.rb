module Temporal
  class Worker
    class Reactor
      module Command
        # NOTE: Unfortunately RBS does not support Structs,
        #       so we have to define these classes in full
        class Start
          attr_reader :block

          def initialize(block)
            @block = block
          end
        end

        class Resume
          attr_reader :fiber, :value

          def initialize(fiber, value)
            @fiber = fiber
            @value = value
          end
        end
      end
    end
  end
end
