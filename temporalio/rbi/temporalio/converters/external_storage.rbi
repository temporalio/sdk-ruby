# typed: true

class Temporalio::Converters::ExternalStorage
  extend T::Sig

  DEFAULT_PAYLOAD_SIZE_THRESHOLD = T.let(T.unsafe(nil), Integer)

  sig { returns(T::Array[Temporalio::Converters::StorageDriver]) }
  attr_reader :drivers

  sig do
    returns(
      T.proc.params(
        context: Temporalio::Converters::StorageDriverSelectContext,
        payload: Temporalio::Api::Common::V1::Payload
      ).returns(T.nilable(Temporalio::Converters::StorageDriver))
    )
  end
  attr_reader :driver_selector

  sig { returns(Integer) }
  attr_reader :payload_size_threshold

  sig do
    params(
      drivers: T::Array[Temporalio::Converters::StorageDriver],
      driver_selector: T.nilable(
        T.proc.params(
          context: Temporalio::Converters::StorageDriverSelectContext,
          payload: Temporalio::Api::Common::V1::Payload
        ).returns(T.nilable(Temporalio::Converters::StorageDriver))
      ),
      payload_size_threshold: Integer
    ).void
  end
  def initialize(drivers:, driver_selector: T.unsafe(nil), payload_size_threshold: T.unsafe(nil)); end

  sig { params(name: String).returns(T.nilable(Temporalio::Converters::StorageDriver)) }
  def driver(name); end
end
