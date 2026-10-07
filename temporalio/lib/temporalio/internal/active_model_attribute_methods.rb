# frozen_string_literal: true

module Temporalio
  module Internal
    module ActiveModelAttributeMethods
      def self.in_concurrent_map_call_stack?(locations)
        paths = locations&.filter_map(&:path) || []
        sdk_path = __FILE__.delete_suffix('internal/active_model_attribute_methods.rb')
        # Sorbet can wrap the validator, but application calls inside cache computation remain illegal.
        caller_paths = paths.reject do |path|
          path.start_with?(sdk_path) || path.include?('/gems/sorbet-runtime-')
        end
        map_path = caller_paths.first
        return false unless map_path&.end_with?('/concurrent/collection/map/mri_map_backend.rb')

        caller_paths.find { |path| path != map_path }
                    &.end_with?('/active_model/attribute_methods.rb') == true
      end

      def self.in_cache_computation_call_stack?(locations)
        locations&.each_cons(2)&.any? do |location, caller_location|
          location&.path&.end_with?('/concurrent/collection/map/mri_map_backend.rb') &&
            caller_location&.path&.end_with?('/active_model/attribute_methods.rb')
        end || false
      end
    end
  end
end
