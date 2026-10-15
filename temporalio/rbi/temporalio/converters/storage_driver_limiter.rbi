# typed: true

class Temporalio::Converters::StorageDriverLimiter
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
