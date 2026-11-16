# frozen_string_literal: true

module Temporalio
  module Internal
    module Client
      # The start-workflow action a schedule update started from. Members the updater leaves unchanged are sent back
      # as the payloads they were described from, since encoding them again would store another copy on every update.
      class DescribedScheduleAction
        attr_reader :raw_info

        def initialize(action, raw_info)
          @raw_info = raw_info
          # Data#with keeps the members it does not replace, and these copies catch a member changed in place.
          @members = %i[args memo headers].to_h do |name|
            value = action.public_send(name)
            [name, [value, value.dup]]
          end
          @texts = %i[static_summary static_details].to_h { |name| [name, action.public_send(name).dup] }
        end

        def unchanged?(name, value)
          described, copy = @members.fetch(name)
          return false unless value.equal?(described)

          case value
          when Array
            copy.is_a?(Array) && value.size == copy.size && value.each_with_index.all? { |v, i| v.equal?(copy[i]) }
          when Hash
            copy.is_a?(Hash) && value.size == copy.size && copy.all? { |k, v| value.key?(k) && value[k].equal?(v) }
          else
            true
          end
        end

        def unchanged_text?(name, value)
          !value.nil? && !value.empty? && value == @texts.fetch(name)
        end
      end
    end
  end
end
