require 'async'

module Temporal
  class AsyncReactor
    def async(&block)
      Async(&block)
    end

    def sync(&block)
      Sync(&block)
    end

    # TODO: Do we need to clean any resources here?
    def terminate; end
  end
end