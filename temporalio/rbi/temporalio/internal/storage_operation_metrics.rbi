# typed: true

class Temporalio::Internal::StorageOperationMetrics
  extend T::Sig

  sig { void }
  def initialize; end

  sig do
    params(
      driver_name: String,
      payload_count: Integer,
      total_size_bytes: Integer,
      start_time: Float,
      end_time: Float
    ).void
  end
  def record(driver_name:, payload_count:, total_size_bytes:, start_time:, end_time:); end

  sig { returns(T.nilable(Temporalio::Internal::Bridge::Api::Common::ExternalStorageMetrics)) }
  def to_proto; end

  private

  sig { returns(Float) }
  def union_seconds; end
end
