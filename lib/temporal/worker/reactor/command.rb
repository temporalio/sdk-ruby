module Temporal
  class Worker
    class Reactor
      module Command
        class Start < Struct.new(:block); end
        class Resume < Struct.new(:fiber, :value); end
      end
    end
  end
end
