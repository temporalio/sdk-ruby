# frozen_string_literal: true

require 'base64'
require 'in_memory_storage_driver'
require 'securerandom'
require 'temporalio/cancellation'
require 'temporalio/converters/external_storage'
require 'temporalio/converters/storage_driver_activity_info'
require 'temporalio/converters/storage_driver_claim'
require 'temporalio/converters/storage_driver_retrieve_context'
require 'temporalio/converters/storage_driver_select_context'
require 'temporalio/converters/storage_driver_store_context'
require 'temporalio/converters/storage_driver_workflow_info'
require 'temporalio/error'
require 'temporalio/internal/external_storage_references'
require 'test'

class ExternalStorageTest < Test
  References = Temporalio::Internal::ExternalStorageReferences

  def test_reference_payload_round_trips
    payload = References.create_reference_payload(
      driver_name: 'mem', claim_data: { 'key' => 'k' }, original_size_bytes: 385
    )

    assert References.reference?(payload)
    assert_equal 'json/protobuf', payload.metadata['encoding']
    assert_equal 'temporal.api.sdk.v1.ExternalStorageReference', payload.metadata['messageType']
    assert_equal 385, payload.external_payloads.first.size_bytes

    reference = References.parse_reference(payload)
    assert_equal 'mem', reference.driver_name
    assert_equal({ 'key' => 'k' }, reference.claim_data.to_h)
  end

  def test_ordinary_payload_is_not_a_reference
    payload = Temporalio::Api::Common::V1::Payload.new(metadata: { 'encoding' => 'json/plain' }, data: '{}')

    refute References.reference?(payload)
    assert_nil References.parse_reference(payload)
  end

  def test_reference_from_another_sdk_parses
    # Verbatim from the Go SDK's TestClaimDeserialization_OtherSdk_ProtoJSON fixture: compact and differently ordered
    # JSON, which is what another SDK actually puts on the wire.
    data = Base64.decode64(
      'eyJjbGFpbURhdGEiOnsiYnVja2V0IjoidGVzdC1idWNrZXQiLCJoYXNoX2FsZ29yaXRobSI6InNoYTI1NiIsImhhc2hfdmFsdWUi' \
      'OiI2Y2EyMmMzNDU2MGNmMzVhYzI0NDI3ZGM3NjE5YzlhYjQ3MmE4MmNmMThmMjg2ZjI3ODcxNjQ5YTJiNTYwOGM4Iiwia2V5Ijoi' \
      'djAvbnMvZGVmYXVsdC93dC9MYXJnZUlPV29ya2Zsb3cvd2kvZjFkMmE0YWMtZjhjYi00NWQzLTkwOGMtOTNhMGYzM2FiMjQ1L3Jp' \
      'L251bGwvZC9zaGEyNTYvNmNhMjJjMzQ1NjBjZjM1YWMyNDQyN2RjNzYxOWM5YWI0NzJhODJjZjE4ZjI4NmYyNzg3MTY0OWEyYjU2' \
      'MDhjOCJ9LCJkcml2ZXJOYW1lIjoiYXdzLnMzZHJpdmVyIn0='
    )
    payload = Temporalio::Api::Common::V1::Payload.new(
      metadata: { 'encoding' => 'json/protobuf', 'messageType' => References::MESSAGE_TYPE },
      data:
    )

    reference = References.parse_reference(payload)

    assert_equal 'aws.s3driver', reference.driver_name
    assert_equal 'test-bucket', reference.claim_data['bucket']
    assert_equal 4, reference.claim_data.size
  end

  def test_single_driver_synthesizes_selector
    driver = InMemoryStorageDriver.new
    storage = Temporalio::Converters::ExternalStorage.new(drivers: [driver])

    assert_equal 256 * 1024, storage.payload_size_threshold
    assert_same driver, storage.driver_selector.call(select_context, payload('x'))
    assert_same driver, storage.driver('mem')
    assert_nil storage.driver('missing')
  end

  def test_no_drivers_rejected
    err = assert_raises(ArgumentError) { Temporalio::Converters::ExternalStorage.new(drivers: []) }
    assert_includes err.message, 'At least one driver'
  end

  def test_empty_driver_name_rejected
    err = assert_raises(ArgumentError) do
      Temporalio::Converters::ExternalStorage.new(drivers: [InMemoryStorageDriver.new(name: '')])
    end
    assert_includes err.message, 'name cannot be empty'
  end

  def test_duplicate_driver_names_rejected
    err = assert_raises(ArgumentError) do
      Temporalio::Converters::ExternalStorage.new(
        drivers: [InMemoryStorageDriver.new(name: 'dup'), InMemoryStorageDriver.new(name: 'dup')],
        driver_selector: ->(_context, _payload) {}
      )
    end
    assert_includes err.message, "name 'dup'"
  end

  def test_multiple_drivers_require_selector
    err = assert_raises(ArgumentError) do
      Temporalio::Converters::ExternalStorage.new(
        drivers: [InMemoryStorageDriver.new(name: 'a'), InMemoryStorageDriver.new(name: 'b')]
      )
    end
    assert_includes err.message, 'driver_selector is required'
  end

  def test_negative_threshold_rejected
    err = assert_raises(ArgumentError) do
      Temporalio::Converters::ExternalStorage.new(drivers: [InMemoryStorageDriver.new], payload_size_threshold: -1)
    end
    assert_includes err.message, 'cannot be negative'
  end

  def test_zero_threshold_allowed
    # Zero offloads every payload rather than disabling offload.
    storage = Temporalio::Converters::ExternalStorage.new(
      drivers: [InMemoryStorageDriver.new], payload_size_threshold: 0
    )

    assert_equal 0, storage.payload_size_threshold
  end

  def test_selector_may_decline
    storage = Temporalio::Converters::ExternalStorage.new(
      drivers: [InMemoryStorageDriver.new], driver_selector: ->(_context, _payload) {}
    )

    assert_nil storage.driver_selector.call(select_context, payload('x'))
  end

  def test_driver_store_and_retrieve_round_trip
    driver = InMemoryStorageDriver.new
    payloads = [payload('one'), payload('two')]

    claims = driver.store(store_context, payloads)
    restored = driver.retrieve(Temporalio::Converters::StorageDriverRetrieveContext.new(cancellation:), claims)

    assert_equal 2, claims.size
    assert_equal payloads, restored
  end

  def test_claims_with_equal_content_are_equal
    first = Temporalio::Converters::StorageDriverClaim.new({ 'a' => '1', 'b' => '2' })
    second = Temporalio::Converters::StorageDriverClaim.new({ 'b' => '2', 'a' => '1' })

    assert_equal first, second
    assert_equal first.hash, second.hash
    assert first.eql?(second)
  end

  def test_claims_with_different_content_are_not_equal
    claim = Temporalio::Converters::StorageDriverClaim.new({ 'key' => 'k' })

    refute_equal claim, Temporalio::Converters::StorageDriverClaim.new({ 'key' => 'other' })
    refute_equal claim, Temporalio::Converters::StorageDriverClaim.new({ 'another' => 'k' })
    refute_equal claim, Temporalio::Converters::StorageDriverClaim.new({ 'key' => 'k', 'x' => 'y' })
    refute_equal claim, 'not a claim'
  end

  def test_target_info_shapes
    workflow = Temporalio::Converters::StorageDriverWorkflowInfo.new(namespace: 'ns', id: 'wf', run_id: 'r',
                                                                     type: 'T')
    activity = Temporalio::Converters::StorageDriverActivityInfo.new(namespace: 'ns')

    assert_equal %w[ns wf r T], [workflow.namespace, workflow.id, workflow.run_id, workflow.type]
    assert_equal 'ns', activity.namespace
    assert_nil activity.id
    assert_nil activity.run_id
    assert_nil activity.type
  end

  def test_not_configured_error_names_its_code
    err = Temporalio::Error::ExternalStorageNotConfiguredError.new

    assert_includes err.message, 'TMPRL1105'
  end

  private

  def cancellation
    Temporalio::Cancellation.new
  end

  def select_context
    Temporalio::Converters::StorageDriverSelectContext.new(target: nil, cancellation:)
  end

  def store_context
    Temporalio::Converters::StorageDriverStoreContext.new(target: nil, cancellation:)
  end

  def payload(data)
    Temporalio::Api::Common::V1::Payload.new(metadata: { 'encoding' => 'json/plain' }, data:)
  end
end
