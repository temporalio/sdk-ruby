# typed: true

module Temporalio::Internal::ProtoUtils
  extend T::Sig

  sig { params(seconds_numeric: T.nilable(T.any(Integer, Float))).returns(T.nilable(Google::Protobuf::Duration)) }
  def self.seconds_to_duration(seconds_numeric); end

  sig { params(duration: T.nilable(Google::Protobuf::Duration)).returns(T.nilable(Float)) }
  def self.duration_to_seconds(duration); end

  sig { params(time: T.nilable(Time)).returns(T.nilable(Google::Protobuf::Timestamp)) }
  def self.time_to_timestamp(time); end

  sig { params(timestamp: T.nilable(Google::Protobuf::Timestamp)).returns(T.nilable(Time)) }
  def self.timestamp_to_time(timestamp); end

  sig do
    params(
      hash: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)
    ).returns(T.nilable(Temporalio::Api::Common::V1::Memo))
  end
  def self.memo_to_proto(hash, converter); end

  sig do
    params(
      hash: T.nilable(T::Hash[T.any(String, Symbol), T.nilable(Object)]),
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)
    ).returns(T.nilable(T::Hash[String, Temporalio::Api::Common::V1::Payload]))
  end
  def self.memo_to_proto_hash(hash, converter); end

  sig do
    params(
      memo: T.nilable(Temporalio::Api::Common::V1::Memo),
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)
    ).returns(T.nilable(T::Hash[String, T.nilable(Object)]))
  end
  def self.memo_from_proto(memo, converter); end

  sig do
    params(
      headers: T.nilable(T::Hash[String, T.nilable(Object)]),
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)
    ).returns(T.nilable(Temporalio::Api::Common::V1::Header))
  end
  def self.headers_to_proto(headers, converter); end

  sig do
    params(
      headers: T.nilable(T::Hash[String, T.nilable(Object)]),
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)
    ).returns(T.nilable(T::Hash[String, Temporalio::Api::Common::V1::Payload]))
  end
  def self.headers_to_proto_hash(headers, converter); end

  sig do
    params(
      headers: T.nilable(Temporalio::Api::Common::V1::Header),
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)
    ).returns(T.nilable(T::Hash[String, T.nilable(Object)]))
  end
  def self.headers_from_proto(headers, converter); end

  sig do
    params(
      headers: T.nilable(Google::Protobuf::Map),
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)
    ).returns(T.nilable(T::Hash[String, Temporalio::Api::Common::V1::Payload]))
  end
  def self.headers_from_proto_map(headers, converter); end

  sig { params(str: T.nilable(String), default: T.nilable(String)).returns(T.nilable(String)) }
  def self.string_or(str, default = nil); end

  sig do
    params(enum_mod: Module, enum_val: T.any(Symbol, Integer, Float), zero_means_nil: T::Boolean)
      .returns(T.nilable(Integer))
  end
  def self.enum_to_int(enum_mod, enum_val, zero_means_nil: false); end

  sig do
    params(
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter),
      payloads: T::Array[Temporalio::Api::Common::V1::Payload],
      hints: T.nilable(T::Array[Object])
    ).returns(T::Array[T.nilable(Object)])
  end
  def self.convert_from_payload_array(converter, payloads, hints:); end

  sig do
    params(
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter),
      values: T::Array[T.nilable(Object)],
      hints: T.nilable(T::Array[Object])
    ).returns(T::Array[Temporalio::Api::Common::V1::Payload])
  end
  def self.convert_to_payload_array(converter, values, hints:); end

  sig { params(name: T.nilable(T.any(String, Symbol))).void }
  def self.assert_non_reserved_name(name); end

  sig { params(name: T.nilable(T.any(String, Symbol))).returns(T::Boolean) }
  def self.reserved_name?(name); end

  sig do
    params(
      summary: T.nilable(String),
      details: T.nilable(String),
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)
    ).returns(T.nilable(Temporalio::Api::Sdk::V1::UserMetadata))
  end
  def self.to_user_metadata(summary, details, converter); end

  sig do
    params(
      metadata: T.nilable(Temporalio::Api::Sdk::V1::UserMetadata),
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)
    ).returns(T::Array[T.nilable(String)])
  end
  def self.from_user_metadata(metadata, converter); end
end

class Temporalio::Internal::ProtoUtils::LazyMemo
  extend T::Sig

  sig do
    params(
      raw_memo: T.nilable(Temporalio::Api::Common::V1::Memo),
      converter: T.any(Temporalio::Converters::DataConverter, Temporalio::Converters::PayloadConverter)
    ).void
  end
  def initialize(raw_memo, converter); end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def get; end
end

class Temporalio::Internal::ProtoUtils::LazySearchAttributes
  extend T::Sig

  sig { params(raw_search_attributes: T.nilable(Temporalio::Api::Common::V1::SearchAttributes)).void }
  def initialize(raw_search_attributes); end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def get; end
end
