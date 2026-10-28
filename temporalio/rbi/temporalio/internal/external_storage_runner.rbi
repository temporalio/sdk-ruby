# typed: true

class Temporalio::Internal::ExternalStorageRunner
  extend T::Sig

  sig { params(storage: T.nilable(Temporalio::Converters::ExternalStorage)).void }
  def initialize(storage); end

  sig do
    params(payloads: T::Array[Temporalio::Api::Common::V1::Payload])
      .returns(T::Array[Temporalio::Api::Common::V1::Payload])
  end
  def store(payloads); end

  sig do
    params(payloads: T::Array[Temporalio::Api::Common::V1::Payload])
      .returns(T::Array[Temporalio::Api::Common::V1::Payload])
  end
  def retrieve(payloads); end
end
