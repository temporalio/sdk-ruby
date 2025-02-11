# frozen_string_literal: true

require 'temporalio/api'

module Temporalio
  # Collection of typed search attributes.
  #
  # This is represented as a mapping of {SearchAttributes::Key} to object values. This is not a hash though it does have
  # a few hash-like methods and can be converted to a hash via {#to_h}. In some situations, such as in workflows, this
  # class is immutable for outside use.
  class SearchAttributes
    # Key for a search attribute.
    class Key
      # @return [String] Name of the search attribute.
      attr_reader :name

      # @return [IndexedValueType] Type of the search attribute.
      attr_reader :type

      def initialize(name, type)
        raise ArgumentError, 'Invalid type' unless Api::Enums::V1::IndexedValueType.lookup(type)

        @name = name.to_s
        @type = type
      end

      # @return [Boolean] Check equality.
      def ==(other)
        other.is_a?(Key) && other.name == @name && other.type == @type
      end

      alias eql? ==

      # @return [Integer] Hash
      def hash
        [self.class, @name, @age].hash
      end

      # Validate that the given value matches the expected {#type}.
      #
      # @raise [TypeError] The value does not have the proper type.
      def validate_value(value)
        case type
        when IndexedValueType::TEXT
          raise TypeError, 'Value of TEXT key must be a String' unless value.is_a?(String)
        when IndexedValueType::KEYWORD
          raise TypeError, 'Value of KEYWORD key must be a String' unless value.is_a?(String)
        when IndexedValueType::INTEGER
          raise TypeError, 'Value of INTEGER key must be a Integer' unless value.is_a?(Integer)
        when IndexedValueType::FLOAT
          unless value.is_a?(Float) || value.is_a?(Integer)
            raise TypeError, 'Value of FLOAT key must be a Float or Integer'
          end
        when IndexedValueType::BOOLEAN
          unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
            raise TypeError, 'Value of BOOLEAN key must be a Boolean'
          end
        when IndexedValueType::TIME
          raise TypeError, 'Value of TIME key must be a Time' unless value.is_a?(Time)
        when IndexedValueType::KEYWORD_LIST
          unless value.is_a?(Array) && value.all? { |v| v.is_a?(String) }
            raise TypeError, 'Value of KEYWORD_LIST key must be an Array of String'
          end
        else
          # Should never happen, checked in constructor
          raise 'Unrecognized key type'
        end
      end

      # Create an updated that sets the given value for this key.
      #
      # @param value [Object] Value to update. Must be the proper type for the key.
      # @return [Update] Created update.
      def value_set(value)
        raise ArgumentError, 'Value cannot be nil, use value_unset' if value.nil?

        Update.new(self, value)
      end

      # Create an updated that unsets the key.
      #
      # @return [Update] Created update.
      def value_unset
        Update.new(self, nil)
      end
    end

    # Search attribute update that can be separately applied.
    class Update
      # @return [Key] Key this update applies to.
      attr_reader :key

      # @return [Object, nil] Value to update or `nil` to remove the key.
      attr_reader :value

      # Create an update. Users may find it easier to use {Key#value_set} and {Key#value_unset} instead.
      #
      # @param key [Key] Key to update.
      # @param value [Object, nil] Value to update to or nil to remove the value.
      def initialize(key, value)
        raise ArgumentError, 'Key must be a key' unless key.is_a?(Key)

        key.validate_value(value) unless value.nil?
        @key = key
        @value = value
      end

      # @!visibility private
      def _to_proto_pair
        SearchAttributes._to_proto_pair(key, value)
      end
    end

    # @!visibility private
    def self._from_proto(proto, disable_mutations: false, never_nil: false)
      return nil unless proto || never_nil

      attrs = if proto
                unless proto.is_a?(Api::Common::V1::SearchAttributes)
                  raise ArgumentError, 'Expected proto search attribute'
                end

                SearchAttributes.new(proto.indexed_fields.map do |key_name, payload| # rubocop:disable Style/MapToHash
                  key = Key.new(key_name, IndexedValueType::PROTO_VALUES[payload.metadata['type']])
                  value = _value_from_payload(payload)
                  [key, value]
                end.to_h)
              else
                SearchAttributes.new
              end
      attrs._disable_mutations = disable_mutations
      attrs
    end

    # @!visibility private
    def self._value_from_payload(payload)
      value = Converters::PayloadConverter.default.from_payload(payload)
      # Time needs to be converted
      value = Time.iso8601(value) if payload.metadata['type'] == 'DateTime' && value.is_a?(String)
      value
    end

    # @!visibility private
    def self._to_proto_pair(key, value)
      # We use a default converter, but if type is a time, we need ISO format
      value = value.iso8601 if key.type == IndexedValueType::TIME && value.is_a?(Time)

      # Convert to payload
      payload = Converters::PayloadConverter.default.to_payload(value)
      payload.metadata['type'] = IndexedValueType::PROTO_NAMES[key.type]

      [key.name, payload]
    end

    # Create a search attribute collection.
    #
    # @param existing [SearchAttributes, Hash<Key, Object>, nil] Existing collection. This can be another
    #   {SearchAttributes} instance or a {::Hash}.
    def initialize(existing = nil)
      if existing.nil?
        @raw_hash = {}
      elsif existing.is_a?(SearchAttributes)
        @raw_hash = existing.to_h
      elsif existing.is_a?(Hash)
        @raw_hash = {}
        existing.each { |key, value| self[key] = value }
      else
        raise ArgumentError, 'Existing must be nil, a SearchAttributes instance, or a valid Hash'
      end
    end

    # Set a search attribute value for a key. This will replace any existing value for the {Key#name }regardless of
    # {Key#type}.
    #
    # @param key [Key] A key to set. This must be a {Key} and the value must be proper for the {Key#type}.
    # @param value [Object, nil] The value to set. If `nil`, the key is removed. The value must be proper for the `key`.
    def []=(key, value)
      _assert_mutations_enabled
      # Key must be a Key
      raise ArgumentError, 'Key must be a key' unless key.is_a?(Key)

      key.validate_value(value) unless value.nil?

      # Remove any key with the same name and set
      delete(key)
      # We only set the value if it's non-nil, otherwise it's a delete
      @raw_hash[key] = value unless value.nil?
    end

    # Get a search attribute value for a key.
    #
    # @param key [Key, String, Symbol] The key to find. If this is a {Key}, it will use key equality (i.e. name and
    #   type) to search. If this is a {::String}, the type is not checked when finding the proper key.
    # @return [Object, nil] Value if found or `nil` if not.
    def [](key)
      # Key must be a Key or a string
      case key
      when Key
        @raw_hash[key]
      when String, Symbol
        @raw_hash.find { |hash_key, _| hash_key.name == key.to_s }&.last
      else
        raise ArgumentError, 'Key must be a key or string/symbol'
      end
    end

    # Delete a search attribute key
    #
    # @param key [Key, String, Symbol] The key to delete. Regardless of whether this is a {Key} or a {::String}, the key
    #   with the matching name will be deleted. This means a {Key} with a matching name but different type may be
    #   deleted.
    def delete(key)
      _assert_mutations_enabled
      # Key must be a Key or a string, but we delete all values for the
      # name no matter what
      name = case key
             when Key
               key.name
             when String, Symbol
               key.to_s
             else
               raise ArgumentError, 'Key must be a key or string/symbol'
             end
      @raw_hash.delete_if { |hash_key, _| hash_key.name == name }
    end

    # Like {::Hash#each}.
    def each(&)
      @raw_hash.each(&)
    end

    # @return [Hash<Key, Object>] Copy of the search attributes as a hash.
    def to_h
      @raw_hash.dup
    end

    # @return [SearchAttributes] Copy of the search attributes.
    def dup
      attrs = SearchAttributes.new(self)
      attrs._disable_mutations = false
      attrs
    end

    # @return [Boolean] Whether the set of attributes is empty.
    def empty?
      length.zero?
    end

    # @return [Integer] Number of attributes.
    def length
      @raw_hash.length
    end

    # Check equality.
    #
    # @param other [SearchAttributes] To compare.
    # @return [Boolean] Whether equal.
    def ==(other)
      other.is_a?(SearchAttributes) && @raw_hash == other._raw_hash
    end

    alias size length

    # Return a new search attributes collection with updates applied.
    #
    # @param updates [Update] Updates created via {Key#value_set} or {Key#value_unset}.
    # @return [SearchAttributes] New collection.
    def update(*updates)
      _assert_mutations_enabled
      attrs = dup
      attrs.update!(*updates)
      attrs
    end

    # Update this search attribute collection with given updates.
    #
    # @param updates [Update] Updates created via {Key#value_set} or {Key#value_unset}.
    def update!(*updates)
      _assert_mutations_enabled
      updates.each do |update|
        raise ArgumentError, 'Update must be an update' unless update.is_a?(Update)

        if update.value.nil?
          delete(update.key)
        else
          self[update.key] = update.value
        end
      end
    end

    # @!visibility private
    def _raw_hash
      @raw_hash
    end

    # @!visibility private
    def _to_proto
      Api::Common::V1::SearchAttributes.new(indexed_fields: _to_proto_hash)
    end

    # @!visibility private
    def _to_proto_hash
      @raw_hash.to_h { |key, value| SearchAttributes._to_proto_pair(key, value) }
    end

    # @!visibility private
    def _assert_mutations_enabled
      raise 'Search attribute mutations disabled' if @disable_mutations
    end

    # @!visibility private
    def _disable_mutations=(value)
      @disable_mutations = value
    end

    # Type for a search attribute key/value.
    #
    # @see https://docs.temporal.io/visibility#supported-types
    module IndexedValueType
      # Text type, values must be {::String}.
      TEXT = Api::Enums::V1::IndexedValueType::INDEXED_VALUE_TYPE_TEXT

      # Keyword type, values must be {::String}.
      KEYWORD = Api::Enums::V1::IndexedValueType::INDEXED_VALUE_TYPE_KEYWORD

      # Integer type, values must be {::Integer}.
      INTEGER = Api::Enums::V1::IndexedValueType::INDEXED_VALUE_TYPE_INT

      # Float type, values must be {::Float} or {::Integer}.
      FLOAT = Api::Enums::V1::IndexedValueType::INDEXED_VALUE_TYPE_DOUBLE

      # Boolean type, values must be {::TrueClass} or {::FalseClass}.
      BOOLEAN = Api::Enums::V1::IndexedValueType::INDEXED_VALUE_TYPE_BOOL

      # Time type, values must be {::Time}.
      TIME = Api::Enums::V1::IndexedValueType::INDEXED_VALUE_TYPE_DATETIME

      # Keyword list type, values must be {::Array<String>}.
      KEYWORD_LIST = Api::Enums::V1::IndexedValueType::INDEXED_VALUE_TYPE_KEYWORD_LIST

      # @!visibility private
      PROTO_NAMES = {
        TEXT => 'Text',
        KEYWORD => 'Keyword',
        INTEGER => 'Int',
        FLOAT => 'Double',
        BOOLEAN => 'Bool',
        TIME => 'DateTime',
        KEYWORD_LIST => 'KeywordList'
      }.freeze

      # @!visibility private
      PROTO_VALUES = PROTO_NAMES.invert.freeze
    end
  end
end
