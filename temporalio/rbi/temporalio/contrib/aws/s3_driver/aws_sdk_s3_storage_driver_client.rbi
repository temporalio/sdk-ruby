# typed: true

class Temporalio::Contrib::Aws::S3Driver::AwsSdkS3StorageDriverClient < Temporalio::Contrib::Aws::S3Driver::S3StorageDriverClient
  extend T::Sig

  sig { params(client: ::Aws::S3::Client).void }
  def initialize(client); end
end
