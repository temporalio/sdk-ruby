# typed: true

class Temporalio::Converters::StorageDriver
  extend T::Sig

  sig { returns(String) }
  def name; end

  sig { returns(String) }
  def type; end

  sig do
    params(
      context: Temporalio::Converters::StorageDriverStoreContext,
      payloads: T::Enumerable[Temporalio::Api::Common::V1::Payload]
    ).returns(T::Array[Temporalio::Converters::StorageDriverClaim])
  end
  def store(context, payloads); end

  sig do
    params(
      context: Temporalio::Converters::StorageDriverRetrieveContext,
      claims: T::Enumerable[Temporalio::Converters::StorageDriverClaim]
    ).returns(T::Array[Temporalio::Api::Common::V1::Payload])
  end
  def retrieve(context, claims); end
end
