# frozen_string_literal: true

require 'temporalio/api/sdk/v1/event_group_marker'
require 'temporalio/converters/payload_converter'

module Temporalio
  module Workflow
    # A discrete token associating workflow commands, and the history events they produce, with a logical group for UI
    # and observability purposes.
    #
    # Multiple Event Groups may be attached to a single command, and a single Event Group may be attached to multiple
    # commands. Instances are created with {Workflow.create_event_group}. Attach them to specific commands via the
    # `event_groups:` option, or to every command produced within a block via {Workflow.with_event_groups}.
    #
    # WARNING: Event Groups is an experimental API and may change without notice.
    class EventGroup
      # @!visibility private
      Active = Struct.new(:implicit, :explicit, keyword_init: true)

      # @!visibility private
      EMPTY_ACTIVE = Active.new(implicit: nil, explicit: {}.freeze).freeze

      # @!visibility private
      STORAGE_KEY = :__temporal_event_groups

      class << self
        # @!visibility private
        def _active
          Fiber[STORAGE_KEY] || EMPTY_ACTIVE
        end

        # @!visibility private
        def _with_active(active)
          prev = Fiber[STORAGE_KEY]
          Fiber[STORAGE_KEY] = active
          yield
        ensure
          Fiber[STORAGE_KEY] = prev
        end

        # @!visibility private
        def _markers_for_command(directs)
          active = _active
          explicit = active.explicit
          if directs
            explicit = explicit.dup
            directs.each do |group|
              unless group.is_a?(Label)
                raise TypeError, 'Event groups must be created with Temporalio::Workflow.create_event_group'
              end

              explicit[group.id] = group
            end
          end
          groups = explicit.values
          groups.unshift(active.implicit) if active.implicit
          groups.filter_map(&:_to_proto)
        end
      end

      # @!visibility private
      def initialize
        raise NotImplementedError, 'Cannot instantiate EventGroup directly, use Temporalio::Workflow.create_event_group'
      end

      # @!visibility private
      def _applied_over(_active)
        raise NotImplementedError
      end

      # @!visibility private
      def _to_proto
        raise NotImplementedError
      end

      # An Event Group explicitly created by workflow code.
      #
      # @!visibility private
      class Label < EventGroup
        attr_reader :id, :label

        def initialize(id, label) # rubocop:disable Lint/MissingSuper
          @id = id
          @label = label
        end

        # @!visibility private
        def _applied_over(active)
          Active.new(implicit: active.implicit, explicit: active.explicit.merge(id => self))
        end

        # @!visibility private
        def _to_proto
          marker_label = Api::Sdk::V1::EventGroupMarker::Label.new(id:)
          # Deliberately the SDK's default converter, not the user-provided one.
          marker_label.label = Converters::PayloadConverter.default.to_payload(label) if label
          Api::Sdk::V1::EventGroupMarker.new(label: marker_label)
        end
      end

      # An Event Group created by the SDK around an inbound signal or update.
      #
      # @!visibility private
      class Implicit < EventGroup
        def initialize(marker) # rubocop:disable Lint/MissingSuper
          @marker = marker
        end

        # @!visibility private
        def _applied_over(_active)
          # Implicit groups do not inherit enclosing explicit scopes: a handler registered inside an explicit scope must
          # not attribute its commands to that scope.
          Active.new(implicit: self, explicit: {})
        end

        # @!visibility private
        def _to_proto
          @marker
        end
      end

      # No-op implicit group used when an inbound event ID is missing or invalid.
      #
      # @!visibility private
      class StubImplicit < EventGroup
        def initialize # rubocop:disable Lint/MissingSuper
        end

        # @!visibility private
        def _applied_over(_active)
          EMPTY_ACTIVE
        end

        # @!visibility private
        def _to_proto
          nil
        end
      end
    end
  end
end
