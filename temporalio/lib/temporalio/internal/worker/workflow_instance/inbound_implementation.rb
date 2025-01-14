# frozen_string_literal: true

require 'temporalio/internal/worker/workflow_instance'
require 'temporalio/worker/interceptor'
require 'temporalio/workflow'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Root implementation of the inbound interceptor.
        class InboundImplementation < Temporalio::Worker::Interceptor::Workflow::Inbound
          def initialize(instance)
            super(nil) # steep:ignore
            @instance = instance
          end

          def init(outbound)
            @instance.context._outbound = outbound
          end

          def execute(input)
            @instance.instance.execute(*input.args)
          end

          def handle_signal(input)
            invoke_handler(input.signal, input)
          end

          def handle_query(input)
            invoke_handler(input.query, input)
          end

          def validate_update(input)
            invoke_handler(input.update, input, to_invoke: input.definition.validator_to_invoke)
          end

          def handle_update(input)
            invoke_handler(input.update, input)
          end

          private

          def invoke_handler(name, input, to_invoke: input.definition.to_invoke)
            args = input.args
            # Add name as first param if dynamic
            args = [name] + args if input.definition.name.nil?
            # Assume symbol or proc
            case to_invoke
            when Symbol
              @instance.instance.send(to_invoke, *args)
            when Proc
              to_invoke.call(*args)
            else
              raise "Unrecognized invocation type #{to_invoke.class}"
            end
          end
        end
      end
    end
  end
end
