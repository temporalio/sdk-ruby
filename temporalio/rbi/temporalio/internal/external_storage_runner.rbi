# typed: true

class Temporalio::Internal::ExternalStorageRunner
  extend T::Sig

  sig do
    params(storage: T.nilable(Temporalio::Converters::ExternalStorage), namespace: T.nilable(String)).void
  end
  def initialize(storage, namespace:); end

  sig do
    params(
      payloads: T::Array[Temporalio::Api::Common::V1::Payload],
      metrics: T.nilable(Temporalio::Internal::StorageOperationMetrics)
    ).returns(T::Array[Temporalio::Api::Common::V1::Payload])
  end
  def store(payloads, metrics: nil); end

  sig do
    params(
      payloads: T::Array[Temporalio::Api::Common::V1::Payload],
      metrics: T.nilable(Temporalio::Internal::StorageOperationMetrics)
    ).returns(T::Array[Temporalio::Api::Common::V1::Payload])
  end
  def retrieve(payloads, metrics: nil); end
end
