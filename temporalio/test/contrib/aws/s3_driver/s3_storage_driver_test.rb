# frozen_string_literal: true

require 'digest'
require 'recording_storage_driver_limiter'
require 'temporalio/cancellation'
require 'temporalio/contrib/aws/s3_driver'
require 'temporalio/converters/storage_driver_activity_info'
require 'temporalio/converters/storage_driver_claim'
require 'temporalio/converters/storage_driver_limiter'
require 'temporalio/converters/storage_driver_retrieve_context'
require 'temporalio/converters/storage_driver_store_context'
require 'temporalio/converters/storage_driver_workflow_info'
require 'test'

module Contrib
  module Aws
    module S3Driver
      class S3StorageDriverTest < Test
        S3StorageDriver = Temporalio::Contrib::Aws::S3Driver::S3StorageDriver

        class FakeS3Client < Temporalio::Contrib::Aws::S3Driver::S3StorageDriverClient
          attr_reader :objects

          def initialize
            super
            @mutex = Mutex.new
            @objects = {}
            @put_count = 0
          end

          def put_count
            @mutex.synchronize { @put_count }
          end

          def put_object(bucket:, key:, data:)
            @mutex.synchronize do
              @put_count += 1
              @objects[[bucket, key]] = data
            end
          end

          def object_exists?(bucket:, key:)
            @mutex.synchronize { @objects.key?([bucket, key]) }
          end

          def get_object(bucket:, key:)
            @mutex.synchronize { @objects.fetch([bucket, key]) }
          end

          def describe
            { 'client_region' => 'us-east-1' }
          end
        end

        class FailingS3Client < Temporalio::Contrib::Aws::S3Driver::S3StorageDriverClient
          def initialize
            super
            @mutex = Mutex.new
            @request_count = 0
          end

          def request_count
            @mutex.synchronize { @request_count }
          end

          def object_exists?(**)
            @mutex.synchronize { @request_count += 1 }
            raise 'access denied'
          end

          def get_object(**)
            @mutex.synchronize { @request_count += 1 }
            raise 'access denied'
          end
        end

        # Holds every request until the thread that made the first one has finished, so the driver has fully
        # handled the first request's outcome before any other request starts
        class FirstRequestFirstLimiter < Temporalio::Converters::StorageDriverLimiter
          def initialize
            super
            @mutex = Mutex.new
            @first_thread = nil
          end

          def permit(_item)
            first_thread = @mutex.synchronize { @first_thread ||= Thread.current }
            first_thread.join unless first_thread == Thread.current
            yield
          end
        end

        # Holds every existence check until the expected number are in flight together, recording the most that ever
        # were
        class ConcurrencyTrackingS3Client < Temporalio::Contrib::Aws::S3Driver::S3StorageDriverClient
          attr_reader :max_in_flight, :request_count

          def initialize(expected_concurrency:)
            super()
            @expected_concurrency = expected_concurrency
            @mutex = Mutex.new
            @expected_concurrency_reached = ConditionVariable.new
            @reached = false
            @in_flight = 0
            @max_in_flight = 0
            @request_count = 0
          end

          def put_object(**); end

          def object_exists?(**)
            @mutex.synchronize do
              @request_count += 1
              @in_flight += 1
              @max_in_flight = [@max_in_flight, @in_flight].max
              if @in_flight == @expected_concurrency
                @reached = true
                @expected_concurrency_reached.broadcast
              end
              @expected_concurrency_reached.wait(@mutex) until @reached
              @in_flight -= 1
            end
            false
          end
        end

        # Marks the thread running the request as holding a permit for as long as the block runs
        class PermitFlaggingLimiter < Temporalio::Converters::StorageDriverLimiter
          def permit(_item)
            Thread.current[:s3_driver_test_permit_held] = true
            yield
          ensure
            Thread.current[:s3_driver_test_permit_held] = false
          end
        end

        class PermitCheckingS3Client < FakeS3Client
          attr_reader :request_count, :requests_without_permit_count

          def initialize
            super
            @request_count = 0
            @requests_without_permit_count = 0
          end

          def put_object(**)
            record_request
            super
          end

          def object_exists?(**)
            record_request
            super
          end

          def get_object(**)
            record_request
            super
          end

          private

          def record_request
            @mutex.synchronize do
              @request_count += 1
              @requests_without_permit_count += 1 unless Thread.current[:s3_driver_test_permit_held]
            end
          end
        end

        class SemaphoreLimiter < Temporalio::Converters::StorageDriverLimiter
          def initialize(permits)
            super()
            @permits = Thread::SizedQueue.new(permits)
          end

          def permit(_item)
            @permits.push(true)
            begin
              yield
            ensure
              @permits.pop
            end
          end
        end

        def test_round_trip
          client = FakeS3Client.new
          driver = S3StorageDriver.new(client:, bucket: 'my-bucket')
          payloads = [payload('one'), payload('two')]

          claims = driver.store(store_context(target: workflow_target), payloads)

          assert_equal payloads, driver.retrieve(retrieve_context, claims)
        end

        def test_claim_data
          driver = S3StorageDriver.new(client: FakeS3Client.new, bucket: 'my-bucket')
          stored = payload('one')

          claim = driver.store(store_context(target: workflow_target), [stored]).first

          hash_value = Digest::SHA256.hexdigest(stored.to_proto)
          assert_equal(
            {
              'bucket' => 'my-bucket',
              'key' => "v0/ns/my-ns/wt/MyWorkflow/wi/my-workflow-id/ri/my-run-id/d/sha256/#{hash_value}",
              'hash_algorithm' => 'sha256',
              'hash_value' => hash_value
            },
            claim.claim_data
          )
        end

        def test_name_and_type
          assert_equal 'aws.s3driver', S3StorageDriver.new(client: FakeS3Client.new, bucket: 'b').name
          driver = S3StorageDriver.new(client: FakeS3Client.new, bucket: 'b', driver_name: 'other')
          assert_equal 'other', driver.name
          assert_equal 'aws.s3driver', driver.type
        end

        def test_workflow_key_is_percent_encoded
          target = Temporalio::Converters::StorageDriverWorkflowInfo.new(
            namespace: 'payments prod', id: 'order+123=abc', run_id: '3f1d6c7a-8b2e-4f7a-9d0a-87a6f95e4d31',
            type: 'ChargeWorkflow'
          )

          assert_equal(
            'v0/ns/payments%20prod/wt/ChargeWorkflow/wi/order%2B123%3Dabc/ri/3f1d6c7a-8b2e-4f7a-9d0a-87a6f95e4d31' \
            "/d/sha256/#{hash_of('one')}",
            store_key(target, 'one')
          )
        end

        def test_activity_key_is_percent_encoded
          target = Temporalio::Converters::StorageDriverActivityInfo.new(
            namespace: 'payments prod', id: 'activity id+42', run_id: '9e1d1fd9-2f8a-4c40-93e2-731f31b9268b',
            type: 'Capture/Charge'
          )

          assert_equal(
            'v0/ns/payments%20prod/at/Capture%2FCharge/ai/activity%20id%2B42/ri/9e1d1fd9-2f8a-4c40-93e2-731f31b9268b' \
            "/d/sha256/#{hash_of('one')}",
            store_key(target, 'one')
          )
        end

        def test_key_keeps_safe_characters_and_escapes_the_rest
          target = Temporalio::Converters::StorageDriverWorkflowInfo.new(
            namespace: "AZaz09!-_.*'()", id: '~é', run_id: 'run-1', type: 'MyWorkflow'
          )

          assert_equal(
            "v0/ns/AZaz09!-_.*'()/wt/MyWorkflow/wi/%7E%C3%A9/ri/run-1/d/sha256/#{hash_of('one')}",
            store_key(target, 'one')
          )
        end

        def test_missing_target_values_become_null
          target = Temporalio::Converters::StorageDriverWorkflowInfo.new(namespace: '', id: nil, run_id: '')

          assert_equal "v0/ns/null/wt/null/wi/null/ri/null/d/sha256/#{hash_of('one')}", store_key(target, 'one')
        end

        def test_no_target_uses_bare_digest_key
          assert_equal "v0/d/sha256/#{hash_of('one')}", store_key(nil, 'one')
        end

        def test_identical_payloads_in_batch_upload_once
          client = FakeS3Client.new
          driver = S3StorageDriver.new(client:, bucket: 'my-bucket')

          claims = driver.store(store_context(target: workflow_target), [payload('same'), payload('same')])

          assert_equal 1, client.put_count
          assert_equal claims.first, claims.last
        end

        def test_existing_object_is_not_uploaded_again
          client = FakeS3Client.new
          driver = S3StorageDriver.new(client:, bucket: 'my-bucket')

          driver.store(store_context(target: workflow_target), [payload('same')])
          driver.store(store_context(target: workflow_target), [payload('same')])

          assert_equal 1, client.put_count
        end

        def test_bucket_selector_is_called_per_payload
          client = FakeS3Client.new
          bucket = ->(_context, payload) { "bucket-#{payload.data}" }
          driver = S3StorageDriver.new(client:, bucket:)

          claims = driver.store(store_context(target: workflow_target), [payload('a'), payload('b')])

          assert_equal(%w[bucket-a bucket-b], claims.map { |claim| claim.claim_data['bucket'] })
          assert_equal(%w[bucket-a bucket-b], client.objects.keys.map(&:first).sort)
        end

        def test_takes_one_permit_per_request
          driver = S3StorageDriver.new(client: FakeS3Client.new, bucket: 'my-bucket')
          payloads = [payload('one'), payload('two'), payload('one')]
          store_limiter = RecordingStorageDriverLimiter.new
          retrieve_limiter = RecordingStorageDriverLimiter.new

          claims = driver.store(store_context(target: workflow_target, limiter: store_limiter), payloads)
          driver.retrieve(retrieve_context(limiter: retrieve_limiter), claims)

          assert_equal [payload('one'), payload('two')].sort_by(&:data), store_limiter.items.sort_by(&:data)
          assert_equal claims.size, retrieve_limiter.items.size
        end

        def test_every_s3_request_runs_while_holding_a_permit
          client = PermitCheckingS3Client.new
          driver = S3StorageDriver.new(client:, bucket: 'my-bucket')

          claims = driver.store(store_context(limiter: PermitFlaggingLimiter.new), [payload('one'), payload('two')])
          driver.retrieve(retrieve_context(limiter: PermitFlaggingLimiter.new), claims)

          assert_equal 6, client.request_count
          assert_equal 0, client.requests_without_permit_count
        end

        def test_runs_as_many_requests_at_once_as_the_limiter_allows
          client = ConcurrencyTrackingS3Client.new(expected_concurrency: 2)
          driver = S3StorageDriver.new(client:, bucket: 'my-bucket')
          payloads = %w[a b c d].map { |data| payload(data) }

          # The client holds requests until two are in flight, so a driver that did not fan out would never finish
          Timeout.timeout(10) { driver.store(store_context(limiter: SemaphoreLimiter.new(2)), payloads) }

          assert_equal 2, client.max_in_flight
          assert_equal 4, client.request_count
        end

        def test_invalid_max_payload_size_is_rejected
          [0, -1].each do |max_payload_size|
            assert_raises(ArgumentError) do
              S3StorageDriver.new(client: FakeS3Client.new, bucket: 'b', max_payload_size:)
            end
          end
        end

        def test_max_payload_size
          stored = payload('one')
          size = stored.to_proto.bytesize
          at_limit = S3StorageDriver.new(client: FakeS3Client.new, bucket: 'b', max_payload_size: size)
          below_limit = S3StorageDriver.new(client: FakeS3Client.new, bucket: 'b', max_payload_size: size - 1)

          at_limit.store(store_context, [stored])
          err = assert_raises(ArgumentError) { below_limit.store(store_context, [stored]) }
          assert_includes err.message, 'exceeds the configured max_payload_size'
        end

        def test_store_failure_is_wrapped_with_location_and_client_info
          client = FailingS3Client.new
          client.define_singleton_method(:describe) { { 'client_region' => 'us-west-2' } }
          driver = S3StorageDriver.new(client:, bucket: 'my-bucket')

          err = assert_raises(RuntimeError) { driver.store(store_context, [payload('one')]) }

          assert_equal(
            "S3StorageDriver store failed [bucket=my-bucket, key=v0/d/sha256/#{hash_of('one')}, " \
            'client_region=us-west-2]',
            err.message
          )
          assert_equal 'access denied', err.cause&.message
        end

        def test_retrieve_failure_is_wrapped
          driver = S3StorageDriver.new(client: FailingS3Client.new, bucket: 'my-bucket')

          err = assert_raises(RuntimeError) { driver.retrieve(retrieve_context, [claim]) }

          assert_equal 'S3StorageDriver retrieve failed [bucket=my-bucket, key=my-key]', err.message
          assert_equal 'access denied', err.cause&.message
        end

        def test_failure_stops_requests_not_yet_started
          client = FailingS3Client.new
          driver = S3StorageDriver.new(client:, bucket: 'my-bucket')
          context = store_context(limiter: FirstRequestFirstLimiter.new)

          assert_raises(RuntimeError) { driver.store(context, [payload('one'), payload('two'), payload('three')]) }
          assert_equal 1, client.request_count
        end

        def test_integrity_check_failure
          client = FakeS3Client.new
          driver = S3StorageDriver.new(client:, bucket: 'my-bucket')
          stored_claim = driver.store(store_context, [payload('one')]).first
          client.objects[['my-bucket', stored_claim.claim_data['key']]] = payload('tampered').to_proto

          err = assert_raises(RuntimeError) { driver.retrieve(retrieve_context, [stored_claim]) }

          assert_includes err.message, 'S3StorageDriver integrity check failed'
        end

        def test_invalid_claims_are_rejected_before_any_request
          client = FailingS3Client.new
          driver = S3StorageDriver.new(client:, bucket: 'my-bucket')
          invalid_claims = [
            claim(bucket: nil),
            claim(key: ''),
            claim(hash_algorithm: nil),
            claim(hash_value: nil),
            claim(hash_algorithm: 'md5')
          ]

          invalid_claims.each do |invalid_claim|
            assert_raises(ArgumentError) { driver.retrieve(retrieve_context, [claim, invalid_claim]) }
          end
          assert_equal 0, client.request_count
        end

        private

        def workflow_target
          Temporalio::Converters::StorageDriverWorkflowInfo.new(
            namespace: 'my-ns', id: 'my-workflow-id', run_id: 'my-run-id', type: 'MyWorkflow'
          )
        end

        def store_context(target: nil, limiter: RecordingStorageDriverLimiter.new)
          Temporalio::Converters::StorageDriverStoreContext.new(
            target:, cancellation: Temporalio::Cancellation.new, limiter:
          )
        end

        def retrieve_context(limiter: RecordingStorageDriverLimiter.new)
          Temporalio::Converters::StorageDriverRetrieveContext.new(cancellation: Temporalio::Cancellation.new, limiter:)
        end

        def payload(data)
          Temporalio::Api::Common::V1::Payload.new(metadata: { 'encoding' => 'json/plain' }, data:)
        end

        def hash_of(data)
          Digest::SHA256.hexdigest(payload(data).to_proto)
        end

        def store_key(target, data)
          driver = S3StorageDriver.new(client: FakeS3Client.new, bucket: 'my-bucket')
          driver.store(store_context(target:), [payload(data)]).first.claim_data['key']
        end

        def claim(bucket: 'my-bucket', key: 'my-key', hash_algorithm: 'sha256', hash_value: 'abc')
          claim_data = {
            'bucket' => bucket, 'key' => key, 'hash_algorithm' => hash_algorithm, 'hash_value' => hash_value
          }
          Temporalio::Converters::StorageDriverClaim.new(claim_data: claim_data.compact)
        end
      end
    end
  end
end
