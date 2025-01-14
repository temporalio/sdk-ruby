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

          # Illegal calls are Hash[String, :all | Hash[Symbol, Bool]]
          def initialize(illegal_calls)
            @tracepoint = TracePoint.new(:call, :c_call) do |tp|
              # Manual check for proper thread since we have seen issues in Ruby 3.2 where it leaks
              next unless Thread.current == @enabled_thread

              cls = tp.defined_class
              next unless cls.is_a?(Module)

              # Extract the class name from the defined class. This is more difficult than it seems because you have to
              # resolve the attached object of the singleton class. But in older Ruby (at least <= 3.1), the singleton
              # class of things like `Date` does not have `attached_object` so you have to fall back in these rare cases
              # to parsing the string output. Reaching the string parsing component is rare, so this should not have
              # significant performance impact.
              cls_name = if cls.singleton_class?
                           if cls.respond_to?(:attached_object)
                             cls = cls.attached_object # steep:ignore
                             next unless cls.is_a?(Module)

                             cls.name.to_s
                           else
                             cls.to_s.delete_prefix('#<Class:').delete_suffix('>')
                           end
                         else
                           cls.name.to_s
                         end

              # Check if the call is considered illegal
              vals = illegal_calls[cls_name]
              if vals == :all || vals&.[](tp.callee_id) # steep:ignore
                raise Workflow::NondeterminismError,
                      "Cannot access #{cls_name} #{tp.callee_id} from inside a " \
                      'workflow. If this is known to be safe, the code can be run in ' \
                      'a Temporalio::Workflow::Unsafe.illegal_call_tracing_disabled block.'
              end
            end
          end

          def enable(&block)
            # We've seen leaking issues in Ruby 3.2 where the TracePoint inadvertently remains enabled even for threads
            # that it was not started on. So we will check the thread ourselves.
            @enabled_thread = Thread.current
            @tracepoint.enable do
              block.call
            ensure
              @enabled_thread = nil
            end
          end

          def disable(&block)
            previous_thread = @enabled_thread
            @tracepoint.disable do
              block.call
            ensure
              @enabled_thread = previous_thread
            end
          end
        end
      end
    end
  end
end
