# frozen_string_literal: true

require 'aws-sdk-s3'
require 'temporalio/contrib/aws/s3_driver/aws_sdk_s3_storage_driver_client'
require 'test'

module Contrib
  module Aws
    module S3Driver
      class AwsSdkS3StorageDriverClientTest < Test
        def test_object_exists
          aws_client = ::Aws::S3::Client.new(stub_responses: true)
          client = Temporalio::Contrib::Aws::S3Driver::AwsSdkS3StorageDriverClient.new(aws_client)

          assert client.object_exists?(bucket: 'my-bucket', key: 'my-key')
          aws_client.stub_responses(:head_object, 'NotFound')
          refute client.object_exists?(bucket: 'my-bucket', key: 'my-key')
        end

        def test_object_exists_raises_errors_other_than_not_found
          aws_client = ::Aws::S3::Client.new(stub_responses: true)
          aws_client.stub_responses(:head_object, 'Forbidden')
          client = Temporalio::Contrib::Aws::S3Driver::AwsSdkS3StorageDriverClient.new(aws_client)

          assert_raises(::Aws::S3::Errors::Forbidden) { client.object_exists?(bucket: 'my-bucket', key: 'my-key') }
        end

        def test_put_object
          aws_client = ::Aws::S3::Client.new(stub_responses: true)
          client = Temporalio::Contrib::Aws::S3Driver::AwsSdkS3StorageDriverClient.new(aws_client)

          client.put_object(bucket: 'my-bucket', key: 'my-key', data: "\x00\x01".b)

          params = aws_client.api_requests.first&.fetch(:params)&.slice(:bucket, :key, :body)
          assert_equal({ bucket: 'my-bucket', key: 'my-key', body: "\x00\x01".b }, params)
        end

        def test_get_object
          aws_client = ::Aws::S3::Client.new(stub_responses: true)
          aws_client.stub_responses(:get_object, { body: "\x00\x01".b })
          client = Temporalio::Contrib::Aws::S3Driver::AwsSdkS3StorageDriverClient.new(aws_client)

          assert_equal "\x00\x01".b, client.get_object(bucket: 'my-bucket', key: 'my-key')
        end

        def test_describe_reports_region
          aws_client = ::Aws::S3::Client.new(stub_responses: true, region: 'us-west-2')
          client = Temporalio::Contrib::Aws::S3Driver::AwsSdkS3StorageDriverClient.new(aws_client)

          assert_equal({ 'client_region' => 'us-west-2' }, client.describe)
        end
      end
    end
  end
end
