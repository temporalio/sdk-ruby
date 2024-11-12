# frozen_string_literal: true

require 'temporalio/workflow'

module Temporalio
  module Internal
    module Worker
      class WorkflowInstance
        # Class that installs {::TracePoint} to disallow illegal calls.
        class IllegalCallTracer
          def self.frozen_validated_illegal_calls(illegal_calls)
            illegal_calls.to_h do |key, val|
              raise TypeError, 'Invalid illegal call map, top-level key must be a String' unless key.is_a?(String)

              # @type var fixed_val: :all | Hash[Symbol, bool]
              fixed_val = case val
                          when Array
                            val.to_h do |sub_val|
                              unless sub_val.is_a?(Symbol)
                                raise TypeError,
                                      'Invalid illegal call map, each value must be a Symbol'
                              end

                              [sub_val, true]
                            end.freeze
                          when :all
                            :all
                          else
                            raise TypeError, 'Invalid illegal call map, top-level value must be an Array or :all'
                          end

              [key.frozen? ? key : key.dup.freeze, fixed_val]
            end.freeze
          end

          # Illegal calls are Hash[String, Hash[Symbol, Bool]]
          def initialize(illegal_calls)
            @tracepoint = TracePoint.new(:call, :c_call) do |tp|
              cls = tp.defined_class
              next unless cls.is_a?(Module)

              # We need this to be quick so we don't do extra validations to satisfy type checker
              # steep:ignore:start
              if cls.singleton_class?
                cls = cls.attached_object
                next unless cls.is_a?(Module)
              end
              vals = illegal_calls[cls.name]
              if vals == :all || vals&.[](tp.callee_id)
                raise Workflow::NondeterminismError,
                      "Cannot access #{cls.name} #{tp.callee_id} from inside a " \
                      'workflow. If this is known to be safe, the code can be run in ' \
                      'a Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled block.'
              end
              # steep:ignore:end
            end
          end

          def enable(&)
            @tracepoint.enable(&)
          end

          def disable(&)
            @tracepoint.disable(&)
          end
        end
      end
    end
  end
end
