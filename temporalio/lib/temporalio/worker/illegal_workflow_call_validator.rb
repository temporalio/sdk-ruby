# frozen_string_literal: true

module Temporalio
  class Worker
    # Custom validator for validating illegal workflow calls.
    class IllegalWorkflowCallValidator
      CallInfo = Data.define(
        :class_name,
        :method_name,
        :trace_point
      )

      # Call info passed to the validation block for each validation.
      #
      # @!attribute class_name
      #   @return [String] Class name the method is on.
      # @!attribute method_name
      #   @return [String] Method name being called.
      # @!attribute trace_point
      #   @return [TracePoint] TracePoint instance for the call.
      class CallInfo; end # rubocop:disable Lint/EmptyClass

      # @return [Array<IllegalWorkflowCallValidator>] Set of advanced validators for Time calls.
      def self.default_time_validators
        @default_time_validators ||= [
          # Do not consider initialize as invalid if year is present and not "true"
          IllegalWorkflowCallValidator.new(method_name: :initialize) do |info|
            year_val = info.trace_point.binding&.local_variable_get(:year)
            raise 'can only use if passing string or explicit time info' unless year_val && year_val != true
          end,
          IllegalWorkflowCallValidator.new(method_name: :now) do
            # When the xmlschema (aliased as iso8601) call is made, zone_offset is called which has a default parameter
            # of Time.now.year. We want to prevent failing in that specific case. It is expensive to access the caller
            # stack, but this is only done in the rare case they are calling this safely.
            next if caller_locations&.any? { |loc| loc.label == 'zone_offset' || loc.label == 'Time.zone_offset' }

            raise 'Invalid Time.now call'
          end
        ]
      end

      # @return [IllegalWorkflowCallValidator] Workflow call validator that is tailored to disallow most Mutex calls,
      #   but let others through for certain situations.
      def self.known_safe_mutex_validator
        @known_safe_mutex_validator ||= IllegalWorkflowCallValidator.new do
          # Only Google Protobuf use of Mutex is known to be safe, fail unless any caller location path has protobuf
          raise 'disallowed' unless caller_locations&.any? { |loc| loc.path&.include?('google/protobuf/') }
        end
      end

      # @return [String, nil] Method name if this validator is specific to a method.
      attr_reader :method_name

      # @return [Proc] Block provided in constructor to invoke. See constructor for more details.
      attr_reader :block

      # Create a call validator.
      #
      # @param method_name [String, nil] Method name to check. This must be provided if the validator is in an illegal
      #   call array, this cannot be provided if it is a top-level class validator.
      # @yield Required block that is called each time validation is needed. If the call raises, the exception message
      #   is used as the reason why the call is considered invalid. Return value is ignored.
      # @yieldparam info [CallInfo] Information about the current call.
      def initialize(method_name: nil, &block)
        raise 'Block required' unless block_given?
        raise TypeError, 'Method name must be Symbol' unless method_name.nil? || method_name.is_a?(Symbol)

        @method_name = method_name
        @block = block
      end
    end
  end
end
