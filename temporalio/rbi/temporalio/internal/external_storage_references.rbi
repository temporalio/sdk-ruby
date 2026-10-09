# typed: true

module Temporalio::Internal::ExternalStorageReferences
  extend T::Sig

  ENCODING = T.let(T.unsafe(nil), String)
  MESSAGE_TYPE = T.let(T.unsafe(nil), String)

  sig { params(payload: Temporalio::Api::Common::V1::Payload).returns(T::Boolean) }
  def self.reference?(payload); end

  sig do
    params(payload: Temporalio::Api::Common::V1::Payload)
      .returns(T.nilable(Temporalio::Api::Sdk::V1::ExternalStorageReference))
  end
  def self.parse_reference(payload); end

  sig do
    params(
      driver_name: String,
      claim_data: T::Hash[String, String],
      original_size_bytes: Integer
    ).returns(Temporalio::Api::Common::V1::Payload)
  end
  def self.create_reference_payload(driver_name:, claim_data:, original_size_bytes:); end
end
