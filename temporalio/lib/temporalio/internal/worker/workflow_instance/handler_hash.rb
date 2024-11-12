# frozen_string_literal: true

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Hash for handlers that notifies when one is added. Only `[]=` and `store` can be used to mutate it.
        class HandlerHash < SimpleDelegator
          def initialize(initial_frozen_hash, definition_class, &on_new_definition)
            super(initial_frozen_hash)
            @definition_class = definition_class
            @on_new_definition = on_new_definition
          end

          def []=(name, definition)
            store(name, definition)
          end

          # steep:ignore:start
          def store(name, definition)
            raise ArgumentError, 'Name must be a string or nil' unless name.nil? || name.is_a?(String)

            unless definition.nil? || definition.is_a?(@definition_class)
              raise ArgumentError,
                    "Value must be a #{@definition_class.name} or nil"
            end
            raise ArgumentError, 'Name does not match one in definition' if definition && name != definition.name

            # Do a copy-on-write op on the underlying frozen hash
            new_hash = __getobj__.dup
            new_hash[name] = definition
            __setobj__(new_hash.freeze)
            @on_new_definition&.call(definition) unless definition.nil?
            definition
          end
          # steep:ignore:end
        end
      end
    end
  end
end
