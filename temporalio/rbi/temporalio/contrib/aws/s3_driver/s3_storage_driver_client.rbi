# typed: true

class Temporalio::Contrib::Aws::S3Driver::S3StorageDriverClient
  extend T::Sig

  sig { params(bucket: String, key: String, data: String).void }
  def put_object(bucket:, key:, data:); end

  sig { params(bucket: String, key: String).returns(T::Boolean) }
  def object_exists?(bucket:, key:); end

  sig { params(bucket: String, key: String).returns(String) }
  def get_object(bucket:, key:); end

  sig { returns(T::Hash[String, String]) }
  def describe; end
end
