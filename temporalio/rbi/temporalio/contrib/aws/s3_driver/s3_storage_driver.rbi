# typed: true

class Temporalio::Contrib::Aws::S3Driver::S3StorageDriver < Temporalio::Converters::StorageDriver
  extend T::Sig

  DRIVER_TYPE = T.let(T.unsafe(nil), String)
  DEFAULT_MAX_PAYLOAD_SIZE = T.let(T.unsafe(nil), Integer)

  sig { returns(String) }
  attr_reader :name

  sig do
    params(
      client: Temporalio::Contrib::Aws::S3Driver::S3StorageDriverClient,
      bucket: T.any(
        String,
        T.proc.params(
          context: Temporalio::Converters::StorageDriverStoreContext,
          payload: Temporalio::Api::Common::V1::Payload
        ).returns(String)
      ),
      driver_name: String,
      max_payload_size: Integer
    ).void
  end
  def initialize(client:, bucket:, driver_name: T.unsafe(nil), max_payload_size: T.unsafe(nil)); end
end
