# typed: true

# Sorbet RBI types for the Temporal Ruby SDK.
# This file was split from rbi/temporalio.rbi by extra/split_rbi.rb.

class Temporalio::SearchAttributes
  sig { params(existing: T.nilable(T.any(Temporalio::SearchAttributes, T::Hash[Temporalio::SearchAttributes::Key, Object]))).void }
  def initialize(existing = nil); end

  sig { params(key: T.any(Temporalio::SearchAttributes::Key, String, Symbol), value: T.nilable(Object)).void }
  def []=(key, value); end

  sig { params(key: Temporalio::SearchAttributes::Key).returns(T.nilable(Object)) }
  def [](key); end

  sig { params(key: T.any(Temporalio::SearchAttributes::Key, String, Symbol)).void }
  def delete(key); end

  sig { params(block: T.proc.params(key: Temporalio::SearchAttributes::Key, value: Object).void).returns(Temporalio::SearchAttributes) }
  def each(&block); end

  sig { returns(T::Hash[Temporalio::SearchAttributes::Key, Object]) }
  def to_h; end

  sig { returns(Temporalio::SearchAttributes) }
  def dup; end

  sig { returns(T::Boolean) }
  def empty?; end

  sig { returns(Integer) }
  def length; end

  sig { returns(Integer) }
  def size; end

  sig { params(updates: Temporalio::SearchAttributes::Update).returns(Temporalio::SearchAttributes) }
  def update(*updates); end

  sig { params(updates: Temporalio::SearchAttributes::Update).void }
  def update!(*updates); end

  sig { params(other: Temporalio::SearchAttributes).returns(T::Boolean) }
  def ==(other); end
end

class Temporalio::SearchAttributes::Key
  sig { params(name: String, type: Integer).void }
  def initialize(name, type); end

  sig { returns(String) }
  attr_reader :name

  sig { returns(Integer) }
  attr_reader :type

  sig { params(value: Object).void }
  def validate_value(value); end

  sig { params(value: Object).returns(Temporalio::SearchAttributes::Update) }
  def value_set(value); end

  sig { returns(Temporalio::SearchAttributes::Update) }
  def value_unset; end

  sig { params(other: T.anything).returns(T::Boolean) }
  def ==(other); end

  sig { params(other: T.anything).returns(T::Boolean) }
  def eql?(other); end

  sig { returns(Integer) }
  def hash; end
end

class Temporalio::SearchAttributes::Update
  sig { params(key: Temporalio::SearchAttributes::Key, value: T.nilable(Object)).void }
  def initialize(key, value); end

  sig { returns(Temporalio::SearchAttributes::Key) }
  attr_reader :key

  sig { returns(T.nilable(Object)) }
  attr_reader :value
end

module Temporalio::SearchAttributes::IndexedValueType
  TEXT = T.let(T.unsafe(nil), Integer)
  KEYWORD = T.let(T.unsafe(nil), Integer)
  INTEGER = T.let(T.unsafe(nil), Integer)
  FLOAT = T.let(T.unsafe(nil), Integer)
  BOOLEAN = T.let(T.unsafe(nil), Integer)
  TIME = T.let(T.unsafe(nil), Integer)
  KEYWORD_LIST = T.let(T.unsafe(nil), Integer)
  PROTO_NAMES = T.let(T.unsafe(nil), T::Hash[Integer, String])
  PROTO_VALUES = T.let(T.unsafe(nil), T::Hash[String, Integer])
end
