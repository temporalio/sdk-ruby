# frozen_string_literal: true

module Temporalio
  module Internal
    module GoogleProtobuf
      def self.in_call_stack?(locations)
        locations&.any? { |loc| loc.path&.include?('google/protobuf/') } || false
      end
    end
  end
end
