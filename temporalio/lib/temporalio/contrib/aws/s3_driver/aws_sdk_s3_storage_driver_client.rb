# frozen_string_literal: true

require 'aws-sdk-s3'
require 'temporalio/contrib/aws/s3_driver/s3_storage_driver_client'

module Temporalio
  module Contrib
    module Aws
      module S3Driver
        # {S3StorageDriverClient} backed by an +Aws::S3::Client+ from the official +aws-sdk-s3+ gem.
        #
        # @note WARNING: This API is experimental and may change in the future.
        #
        # @!visibility private
        class AwsSdkS3StorageDriverClient < S3StorageDriverClient
          # Create a client.
          #
          # @param client [Aws::S3::Client] AWS S3 client to make requests with.
          def initialize(client)
            super()
            @client = client
          end

          # (see S3StorageDriverClient#put_object)
          def put_object(bucket:, key:, data:)
            @client.put_object(bucket:, key:, body: data)
            nil
          end

          # (see S3StorageDriverClient#object_exists?)
          def object_exists?(bucket:, key:)
            @client.head_object(bucket:, key:)
            true
          rescue ::Aws::S3::Errors::NotFound
            false
          end

          # (see S3StorageDriverClient#get_object)
          def get_object(bucket:, key:)
            @client.get_object(bucket:, key:).body.read
          end

          # (see S3StorageDriverClient#describe)
          def describe
            region = @client.config.region
            region.nil? || region.empty? ? {} : { 'client_region' => region }
          end
        end
      end
    end
  end
end
