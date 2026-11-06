# frozen_string_literal: true

require 'temporalio/contrib/aws/s3_driver/s3_storage_driver'
require 'temporalio/contrib/aws/s3_driver/s3_storage_driver_client'

module Temporalio
  module Contrib
    # Integrations with Amazon Web Services.
    module Aws
      # External storage driver for Amazon S3.
      #
      # This does not load the +aws-sdk-s3+ gem, so a custom {S3StorageDriverClient} can be used without it. Require
      # +temporalio/contrib/aws/s3_driver/aws_sdk_s3_storage_driver_client+ to use the official AWS client.
      #
      # @note WARNING: This API is experimental and may change in the future.
      #
      # @!visibility private
      module S3Driver
      end
    end
  end
end
