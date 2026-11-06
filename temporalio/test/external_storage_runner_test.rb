# frozen_string_literal: true

require 'in_memory_storage_driver'
require 'temporalio/converters/external_storage'
require 'temporalio/error'
require 'temporalio/internal/external_storage_references'
require 'temporalio/internal/external_storage_runner'
require 'test'

class ExternalStorageRunnerTest < Test
  Runner = Temporalio::Internal::ExternalStorageRunner
  References = Temporalio::Internal::ExternalStorageReferences

  def test_store_replaces_only_payloads_at_or_above_threshold
    driver = InMemoryStorageDriver.new
    small = payload('a')
    at_threshold = payload('bb')
    threshold = at_threshold.to_proto.bytesize
    runner = Runner.new(storage(driver, payload_size_threshold: threshold))

    stored = runner.store([small, at_threshold])

    assert_same small, stored[0]
    assert References.reference?(stored[1])
    assert_equal threshold, stored[1].external_payloads.first.size_bytes
    assert_equal 'mem', References.parse_reference(stored[1]).driver_name
  end

  def test_store_then_retrieve_returns_original_payloads_in_one_batch
    driver = InMemoryStorageDriver.new
    runner = Runner.new(storage(driver))
    originals = [payload('a'), payload('b'), payload('c')]

    stored = runner.store(originals)
    retrieved = runner.retrieve(stored)

    assert_equal originals, retrieved
    assert_equal([3], driver.store_calls.map { |_, count| count })
    assert_equal [3], driver.retrieve_calls
  end

  def test_store_sends_one_batch_to_each_selected_driver
    one = InMemoryStorageDriver.new(name: 'one')
    two = InMemoryStorageDriver.new(name: 'two')
    runner = Runner.new(Temporalio::Converters::ExternalStorage.new(
                          drivers: [one, two],
                          driver_selector: ->(_context, payload) { payload.data == '"a"' ? one : two },
                          payload_size_threshold: 0
                        ))

    stored = runner.store([payload('a'), payload('b'), payload('c')])

    assert_equal(%w[one two two], stored.map { |p| References.parse_reference(p).driver_name })
    assert_equal([1], one.store_calls.map { |_, count| count })
    assert_equal([2], two.store_calls.map { |_, count| count })
  end

  def test_store_keeps_payload_inline_when_selector_returns_nil
    driver = InMemoryStorageDriver.new
    runner = Runner.new(Temporalio::Converters::ExternalStorage.new(
                          drivers: [driver], driver_selector: ->(_context, _payload) {}, payload_size_threshold: 0
                        ))
    original = payload('a')

    assert_same original, runner.store([original]).first
    assert_empty driver.store_calls
  end

  def test_store_raises_when_selector_returns_unregistered_driver
    lookalike = InMemoryStorageDriver.new
    runner = Runner.new(Temporalio::Converters::ExternalStorage.new(
                          drivers: [InMemoryStorageDriver.new],
                          driver_selector: ->(_context, _payload) { lookalike },
                          payload_size_threshold: 0
                        ))

    err = assert_raises(Temporalio::Error) { runner.store([payload('a')]) }
    assert_includes err.message, 'not registered'
  end

  def test_retrieve_raises_when_reference_names_unregistered_driver
    reference = References.create_reference_payload(
      driver_name: 'missing', claim_data: { 'key' => 'k' }, original_size_bytes: 1
    )

    err = assert_raises(Temporalio::Error) { Runner.new(storage(InMemoryStorageDriver.new)).retrieve([reference]) }
    assert_includes err.message, "'missing'"
  end

  def test_store_raises_when_driver_returns_wrong_number_of_claims
    driver = InMemoryStorageDriver.new
    driver.define_singleton_method(:store) { |_context, _payloads| [] }

    err = assert_raises(Temporalio::Error) { Runner.new(storage(driver)).store([payload('a')]) }
    assert_includes err.message, 'given 1 item(s) but returned 0'
  end

  def test_without_storage_store_and_retrieve_leave_payloads_unchanged
    original = payload('a')
    runner = Runner.new(nil)

    assert_same original, runner.store([original]).first
    assert_same original, runner.retrieve([original]).first
  end

  def test_without_storage_retrieve_raises_on_reference
    reference = References.create_reference_payload(
      driver_name: 'mem', claim_data: { 'key' => 'k' }, original_size_bytes: 1
    )

    assert_raises(Temporalio::Error::ExternalStorageNotConfiguredError) { Runner.new(nil).retrieve([reference]) }
  end

  private

  def storage(driver, payload_size_threshold: 0)
    Temporalio::Converters::ExternalStorage.new(drivers: [driver], payload_size_threshold:)
  end

  def payload(value)
    Temporalio::Api::Common::V1::Payload.new(metadata: { 'encoding' => 'json/plain' }, data: "\"#{value}\"")
  end
end
