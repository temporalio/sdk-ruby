# frozen_string_literal: true

require 'digest'
require 'temporalio/api'
require 'temporalio/cancellation'
require 'temporalio/contrib/aws/s3_driver/s3_storage_driver_client'
require 'temporalio/converters/storage_driver'
require 'temporalio/converters/storage_driver_activity_info'
require 'temporalio/converters/storage_driver_claim'
require 'temporalio/converters/storage_driver_workflow_info'

module Temporalio
  module Contrib
    module Aws
      module S3Driver
        # Storage driver that stores and retrieves payloads in Amazon S3.
        #
        # Payloads are content addressed by a SHA-256 hash of their serialized bytes, so storing the same payload twice
        # for the same execution uploads it once. Object keys are built from the namespace and the workflow or activity
        # the payload is stored for, percent-encoded to S3's safe character set.
        #
        # @note WARNING: This API is experimental and may change in the future.
        #
        # @!visibility private
        class S3StorageDriver < Converters::StorageDriver
          # Driver type shared by every S3 driver instance across SDK languages.
          DRIVER_TYPE = 'aws.s3driver'

          # Default maximum serialized payload size, in bytes.
          DEFAULT_MAX_PAYLOAD_SIZE = 50 * 1024 * 1024

          CLAIM_BUCKET = 'bucket'
          CLAIM_KEY = 'key'
          CLAIM_HASH_ALGORITHM = 'hash_algorithm'
          CLAIM_HASH_VALUE = 'hash_value'
          NULL_SEGMENT = 'null'
          private_constant :CLAIM_BUCKET, :CLAIM_KEY, :CLAIM_HASH_ALGORITHM, :CLAIM_HASH_VALUE, :NULL_SEGMENT

          StoredObject = Data.define(:payload, :bucket, :key, :hash_value, :data)
          private_constant :StoredObject

          # @return [String] Driver instance name.
          attr_reader :name

          # Create an S3 storage driver.
          #
          # @param client [S3StorageDriverClient] Client that performs the S3 requests, for example an
          #   {AwsSdkS3StorageDriverClient}.
          # @param bucket [String, Proc] Bucket name, or a proc called with the {Converters::StorageDriverStoreContext}
          #   and the payload that returns the bucket name for that payload.
          # @param driver_name [String] Driver instance name written into history. Only change this when registering
          #   multiple S3 drivers with different configurations on the same external storage.
          # @param max_payload_size [Integer] Maximum serialized payload size, in bytes. Storing a larger payload
          #   raises.
          def initialize(client:, bucket:, driver_name: DRIVER_TYPE, max_payload_size: DEFAULT_MAX_PAYLOAD_SIZE)
            super()
            unless max_payload_size.is_a?(Integer) && max_payload_size.positive?
              raise ArgumentError, "max_payload_size must be a positive integer, got #{max_payload_size.inspect}"
            end

            @client = client
            @bucket = bucket.is_a?(String) ? proc { bucket } : bucket
            @name = driver_name
            @max_payload_size = max_payload_size
          end

          # @return [String] Always {DRIVER_TYPE}.
          def type
            DRIVER_TYPE
          end

          # (see Converters::StorageDriver#store)
          def store(context, payloads)
            context_segments = context_key_segments(context.target)
            objects = payloads.map { |payload| stored_object(context, payload, context_segments) }
            uploads = objects.uniq { |object| [object.bucket, object.key] }
            run_concurrently(uploads, context.cancellation) do |object, cancellation|
              context.limiter.permit(object.payload) do
                cancellation.check!
                upload_if_absent(object)
              end
            end
            objects.map do |object|
              Converters::StorageDriverClaim.new(
                claim_data: {
                  CLAIM_BUCKET => object.bucket,
                  CLAIM_KEY => object.key,
                  CLAIM_HASH_ALGORITHM => 'sha256',
                  CLAIM_HASH_VALUE => object.hash_value
                }
              )
            end
          end

          # (see Converters::StorageDriver#retrieve)
          def retrieve(context, claims)
            claims.each { |claim| validate_claim(claim) }
            run_concurrently(claims.to_a, context.cancellation) do |claim, cancellation|
              bucket = claim.claim_data.fetch(CLAIM_BUCKET)
              key = claim.claim_data.fetch(CLAIM_KEY)
              expected_hash = claim.claim_data.fetch(CLAIM_HASH_VALUE)
              data = context.limiter.permit(claim) do
                cancellation.check!
                download(bucket, key)
              end
              actual_hash = Digest::SHA256.hexdigest(data)
              if actual_hash != expected_hash
                raise "S3StorageDriver integrity check failed [bucket=#{bucket}, key=#{key}]: " \
                      "expected sha256:#{expected_hash}, got sha256:#{actual_hash}"
              end
              Api::Common::V1::Payload.decode(data)
            end
          end

          private

          def stored_object(context, payload, context_segments)
            bucket = @bucket.call(context, payload)
            data = serialize_payload(payload)
            if data.bytesize > @max_payload_size
              raise ArgumentError, "Payload size #{data.bytesize} bytes exceeds the configured max_payload_size " \
                                   "of #{@max_payload_size} bytes"
            end
            hash_value = Digest::SHA256.hexdigest(data)
            StoredObject.new(payload:, bucket:, key: "v0#{context_segments}/d/sha256/#{hash_value}", hash_value:, data:)
          end

          # Serializes the payload with its metadata entries sorted by key.
          def serialize_payload(payload)
            data = String.new(encoding: Encoding::BINARY)
            payload.metadata.sort.each do |key, value|
              data << Api::Common::V1::Payload.new(metadata: { key => value }).to_proto
            end
            # steep:ignore:start
            without_metadata = Google::Protobuf.deep_copy(payload)
            # steep:ignore:end
            without_metadata.metadata.clear
            data << without_metadata.to_proto
          end

          def upload_if_absent(object)
            return if @client.object_exists?(bucket: object.bucket, key: object.key)

            @client.put_object(bucket: object.bucket, key: object.key, data: object.data)
          rescue StandardError
            raise "S3StorageDriver store failed [bucket=#{object.bucket}, key=#{object.key}#{client_context}]"
          end

          def download(bucket, key)
            @client.get_object(bucket:, key:)
          rescue StandardError
            raise "S3StorageDriver retrieve failed [bucket=#{bucket}, key=#{key}#{client_context}]"
          end

          def validate_claim(claim)
            bucket, key, hash_algorithm, hash_value =
              claim.claim_data.values_at(CLAIM_BUCKET, CLAIM_KEY, CLAIM_HASH_ALGORITHM, CLAIM_HASH_VALUE)
            if bucket.nil? || bucket.empty? || key.nil? || key.empty?
              raise ArgumentError, 'S3StorageDriver claim is missing required location information: ' \
                                   "claim_data must contain 'bucket' and 'key'"
            end
            if hash_algorithm.nil? || hash_algorithm.empty? || hash_value.nil? || hash_value.empty?
              raise ArgumentError, 'S3StorageDriver claim is missing required content hash information ' \
                                   "[bucket=#{bucket}, key=#{key}]: claim_data must contain 'hash_algorithm' and " \
                                   "'hash_value'"
            end
            return if hash_algorithm == 'sha256'

            raise ArgumentError, "S3StorageDriver unsupported hash algorithm [bucket=#{bucket}, key=#{key}]: " \
                                 "expected sha256, got #{hash_algorithm}"
          end

          # Each request blocks on I/O, so every item gets its own thread. The first failure cancels the rest so they
          # stop before making further requests. Requests already in flight run to completion, since a blocking S3
          # call cannot be safely interrupted.
          def run_concurrently(items, parent_cancellation, &block)
            cancellation, cancel_proc = Cancellation.new(parent_cancellation)
            mutex = Mutex.new
            first_error = nil #: StandardError?
            threads = items.map do |item|
              Thread.new do
                block.call(item, cancellation)
              rescue StandardError => e
                mutex.synchronize { first_error ||= e }
                cancel_proc.call
                nil
              end
            end
            results = threads.map(&:value)
            raise first_error if first_error

            results
          end

          def context_key_segments(target)
            case target
            when Converters::StorageDriverWorkflowInfo
              "/ns/#{encode_key_segment(target.namespace)}/wt/#{encode_key_segment(target.type)}" \
              "/wi/#{encode_key_segment(target.id)}/ri/#{encode_key_segment(target.run_id)}"
            when Converters::StorageDriverActivityInfo
              "/ns/#{encode_key_segment(target.namespace)}/at/#{encode_key_segment(target.type)}" \
              "/ai/#{encode_key_segment(target.id)}/ri/#{encode_key_segment(target.run_id)}"
            else
              ''
            end
          end

          # Escapes every UTF-8 byte outside S3's safe character set so keys are portable across S3 implementations
          # and identical to the keys other SDK languages build.
          def encode_key_segment(value)
            return NULL_SEGMENT if value.nil? || value.empty?

            encoded = value.b.gsub(/[^A-Za-z0-9!\-_.*'()]/n) { |byte| format('%%%02X', byte.ord) }
            encoded.force_encoding(Encoding::UTF_8)
          end

          def client_context
            @client.describe.map { |key, value| ", #{key}=#{value}" }.join
          rescue StandardError
            ''
          end
        end
      end
    end
  end
end
