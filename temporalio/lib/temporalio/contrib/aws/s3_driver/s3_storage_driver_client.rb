# frozen_string_literal: true

module Temporalio
  module Contrib
    module Aws
      module S3Driver
        # S3 object operations used by {S3StorageDriver}.
        #
        # This is kept separate from any particular S3 library so the driver does not depend on one. Use
        # {AwsSdkS3StorageDriverClient} for the official +aws-sdk-s3+ gem, or subclass this to bring another client.
        #
        # Implementations are called concurrently from multiple threads and must be thread safe.
        #
        # @note WARNING: This API is experimental and may change in the future.
        #
        # @!visibility private
        class S3StorageDriverClient
          # Upload data to the given bucket and key.
          #
          # @param bucket [String] Bucket name.
          # @param key [String] Object key.
          # @param data [String] Binary data to upload.
          def put_object(bucket:, key:, data:)
            raise NotImplementedError
          end

          # Check whether an object exists at the given bucket and key.
          #
          # @param bucket [String] Bucket name.
          # @param key [String] Object key.
          # @return [Boolean] Whether the object exists.
          def object_exists?(bucket:, key:)
            raise NotImplementedError
          end

          # Download the object at the given bucket and key.
          #
          # @param bucket [String] Bucket name.
          # @param key [String] Object key.
          # @return [String] Binary object data.
          def get_object(bucket:, key:)
            raise NotImplementedError
          end

          # Client-specific diagnostic information, such as the region, that the driver appends to error messages to
          # help diagnose misconfiguration.
          #
          # @return [Hash<String, String>] Diagnostic information. Empty by default.
          def describe
            {}
          end
        end
      end
    end
  end
end
