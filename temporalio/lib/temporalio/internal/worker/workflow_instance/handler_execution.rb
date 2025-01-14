# frozen_string_literal: true

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Representation of a currently-executing handler. Used to track whether any handlers are still running and warn
        # on workflow complete as needed.
        class HandlerExecution
          attr_reader :name, :update_id, :unfinished_policy

          def initialize(
            name:,
            update_id:,
            unfinished_policy:
          )
            @name = name
            @update_id = update_id
            @unfinished_policy = unfinished_policy
          end
        end
      end
    end
  end
end
