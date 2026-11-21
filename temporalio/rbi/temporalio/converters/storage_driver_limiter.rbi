# typed: true

class Temporalio::Converters::StorageDriverLimiter
  UNBOUNDED = T.let(T.unsafe(nil), Temporalio::Converters::StorageDriverLimiter::Unbounded)

  sig do
    type_parameters(:T)
      .params(
        item: T.any(Temporalio::Api::Common::V1::Payload, Temporalio::Converters::StorageDriverClaim),
        blk: T.proc.returns(T.type_parameter(:T))
      )
      .returns(T.type_parameter(:T))
  end
  def permit(item, &blk); end
end

class Temporalio::Converters::StorageDriverLimiter::Unbounded < Temporalio::Converters::StorageDriverLimiter; end
