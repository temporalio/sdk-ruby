# frozen_string_literal: true

require 'in_memory_storage_driver'
require 'temporalio/converters/external_storage'
require 'temporalio/converters/storage_driver_activity_info'
require 'temporalio/converters/storage_driver_workflow_info'
require 'temporalio/error'
require 'temporalio/internal/external_storage_references'
require 'temporalio/internal/external_storage_runner'
require 'temporalio/internal/storage_operation_metrics'
require 'test'

class ExternalStorageRunnerTest < Test
  Runner = Temporalio::Internal::ExternalStorageRunner
  References = Temporalio::Internal::ExternalStorageReferences

  class FakeClock
    attr_reader :now

    def initialize
      @now = 0.0
    end

    def advance(seconds)
      @now += seconds
    end
  end

  # Moves the fake clock forward during each call, so the time measured around a call is exactly the given seconds.
  class ClockAdvancingDriver < InMemoryStorageDriver
    def initialize(clock:, seconds:, name:)
      super(name:)
      @clock = clock
      @seconds = seconds
    end

    def store(context, payloads)
      @clock.advance(@seconds)
      super
    end

    def retrieve(context, claims)
      @clock.advance(@seconds)
      super
    end
  end

  def test_store_replaces_only_payloads_at_or_above_threshold
    driver = InMemoryStorageDriver.new
    small = payload('a')
    at_threshold = payload('bb')
    threshold = at_threshold.to_proto.bytesize
    runner = Runner.new(storage(driver, payload_size_threshold: threshold), namespace: nil)

    stored = runner.store([small, at_threshold])

    assert_same small, stored[0]
    assert References.reference?(stored[1])
    assert_equal threshold, stored[1].external_payloads.first.size_bytes
    assert_equal 'mem', References.parse_reference(stored[1]).driver_name
  end

  def test_store_then_retrieve_returns_original_payloads_in_one_batch
    driver = InMemoryStorageDriver.new
    runner = Runner.new(storage(driver), namespace: nil)
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
                        ), namespace: nil)

    stored = runner.store([payload('a'), payload('b'), payload('c')])

    assert_equal(%w[one two two], stored.map { |p| References.parse_reference(p).driver_name })
    assert_equal([1], one.store_calls.map { |_, count| count })
    assert_equal([2], two.store_calls.map { |_, count| count })
  end

  def test_store_gives_selector_and_driver_the_namespace
    driver = InMemoryStorageDriver.new
    select_contexts = []
    runner = Runner.new(Temporalio::Converters::ExternalStorage.new(
                          drivers: [driver],
                          driver_selector: lambda { |context, _payload|
                            select_contexts << context
                            driver
                          },
                          payload_size_threshold: 0
                        ), namespace: 'my-namespace')

    runner.store([payload('a')])

    assert_equal ['my-namespace'], select_contexts.map(&:namespace)
    assert_equal(['my-namespace'], driver.store_calls.map { |context, _size| context.namespace })
  end

  def test_store_gives_selector_and_driver_the_target
    driver = InMemoryStorageDriver.new
    select_contexts = []
    runner = Runner.new(Temporalio::Converters::ExternalStorage.new(
                          drivers: [driver],
                          driver_selector: lambda { |context, _payload|
                            select_contexts << context
                            driver
                          },
                          payload_size_threshold: 0
                        ), namespace: 'my-namespace')
    workflow_target = Temporalio::Converters::StorageDriverWorkflowInfo.new(namespace: 'my-namespace', id: 'wf')
    activity_target = Temporalio::Converters::StorageDriverActivityInfo.new(namespace: 'my-namespace', id: 'act')

    runner.store([payload('a'), payload('b')], target: workflow_target)
    runner.store([payload('c')], target: activity_target)

    assert_equal [workflow_target, workflow_target, activity_target], select_contexts.map(&:target)
    assert_equal(
      [[workflow_target, 2], [activity_target, 1]],
      driver.store_calls.map { |context, payload_count| [context.target, payload_count] }
    )
  end

  def test_store_keeps_payload_inline_when_selector_returns_nil
    driver = InMemoryStorageDriver.new
    runner = Runner.new(Temporalio::Converters::ExternalStorage.new(
                          drivers: [driver], driver_selector: ->(_context, _payload) {}, payload_size_threshold: 0
                        ), namespace: nil)
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
                        ), namespace: nil)

    err = assert_raises(Temporalio::Error::ExternalStorageError) { runner.store([payload('a')]) }
    assert_includes err.message, 'not registered'
  end

  def test_retrieve_raises_when_reference_names_unregistered_driver
    reference = References.create_reference_payload(
      driver_name: 'missing', claim_data: { 'key' => 'k' }, original_size_bytes: 1
    )

    err = assert_raises(Temporalio::Error::ExternalStorageError) { Runner.new(storage(InMemoryStorageDriver.new), namespace: nil).retrieve([reference]) }
    assert_includes err.message, "'missing'"
  end

  def test_store_raises_when_driver_returns_wrong_number_of_claims
    driver = InMemoryStorageDriver.new
    driver.define_singleton_method(:store) { |_context, _payloads| [] }

    err = assert_raises(Temporalio::Error::ExternalStorageError) { Runner.new(storage(driver), namespace: nil).store([payload('a')]) }
    assert_includes err.message, 'given 1 item(s) but returned 0'
  end

  def test_store_wraps_driver_error_naming_the_driver
    driver = InMemoryStorageDriver.new
    driver.define_singleton_method(:store) { |_context, _payloads| raise 'Intentional store failure' }

    err = assert_raises(Temporalio::Error::ExternalStorageError) do
      Runner.new(storage(driver), namespace: nil).store([payload('a')])
    end
    assert_equal "External storage driver 'mem' failed to store payloads: Intentional store failure", err.message
    assert_instance_of RuntimeError, err.cause
  end

  def test_retrieve_wraps_driver_error_naming_the_driver
    driver = InMemoryStorageDriver.new
    runner = Runner.new(storage(driver), namespace: nil)
    stored = runner.store([payload('a')])
    driver.define_singleton_method(:retrieve) { |_context, _claims| raise 'Intentional retrieve failure' }

    err = assert_raises(Temporalio::Error::ExternalStorageError) { runner.retrieve(stored) }
    assert_equal "External storage driver 'mem' failed to retrieve payloads: Intentional retrieve failure",
                 err.message
    assert_instance_of RuntimeError, err.cause
  end

  def test_driver_cancellation_is_not_wrapped
    driver = InMemoryStorageDriver.new
    driver.define_singleton_method(:store) do |_context, _payloads|
      raise Temporalio::Error::CanceledError, 'Activity canceled'
    end

    assert_raises(Temporalio::Error::CanceledError) { Runner.new(storage(driver), namespace: nil).store([payload('a')]) }
  end

  def test_driver_storage_error_is_not_wrapped_again
    driver = InMemoryStorageDriver.new
    driver.define_singleton_method(:store) do |_context, _payloads|
      raise Temporalio::Error::ExternalStorageError, 'Driver storage error'
    end

    err = assert_raises(Temporalio::Error::ExternalStorageError) do
      Runner.new(storage(driver), namespace: nil).store([payload('a')])
    end
    assert_equal 'Driver storage error', err.message
    assert_nil err.cause
  end

  def test_store_wraps_selector_error
    runner = Runner.new(Temporalio::Converters::ExternalStorage.new(
                          drivers: [InMemoryStorageDriver.new],
                          driver_selector: ->(_context, _payload) { raise 'Intentional selector failure' },
                          payload_size_threshold: 0
                        ), namespace: nil)

    err = assert_raises(Temporalio::Error::ExternalStorageError) { runner.store([payload('a')]) }
    assert_equal 'External storage driver selector failed: Intentional selector failure', err.message
    assert_instance_of RuntimeError, err.cause
  end

  def test_store_raises_when_driver_returns_something_other_than_claims
    driver = InMemoryStorageDriver.new
    driver.define_singleton_method(:store) { |_context, _payloads| [{ 'key' => 'k' }] }

    err = assert_raises(Temporalio::Error::ExternalStorageError) do
      Runner.new(storage(driver), namespace: nil).store([payload('a')])
    end
    assert_includes err.message, 'instead of a Temporalio::Converters::StorageDriverClaim'
  end

  def test_retrieve_raises_when_driver_returns_something_other_than_payloads
    driver = InMemoryStorageDriver.new
    runner = Runner.new(storage(driver), namespace: nil)
    stored = runner.store([payload('a')])
    driver.define_singleton_method(:retrieve) { |_context, _claims| ['not a payload'] }

    err = assert_raises(Temporalio::Error::ExternalStorageError) { runner.retrieve(stored) }
    assert_includes err.message, 'instead of a Temporalio::Api::Common::V1::Payload'
  end

  def test_retrieve_raises_storage_error_on_malformed_reference
    reference = References.create_reference_payload(
      driver_name: 'mem', claim_data: { 'key' => 'k' }, original_size_bytes: 1
    )
    reference.data = 'not json'

    err = assert_raises(Temporalio::Error::ExternalStorageError) do
      Runner.new(storage(InMemoryStorageDriver.new), namespace: nil).retrieve([reference])
    end
    assert_instance_of Google::Protobuf::ParseError, err.cause
  end

  def test_without_storage_store_and_retrieve_leave_payloads_unchanged
    original = payload('a')
    runner = Runner.new(nil, namespace: nil)

    assert_same original, runner.store([original]).first
    assert_same original, runner.retrieve([original]).first
  end

  def test_without_storage_retrieve_raises_on_reference
    reference = References.create_reference_payload(
      driver_name: 'mem', claim_data: { 'key' => 'k' }, original_size_bytes: 1
    )

    assert_raises(Temporalio::Error::ExternalStorageNotConfiguredError) { Runner.new(nil, namespace: nil).retrieve([reference]) }
  end

  def test_store_and_retrieve_record_metrics_for_each_driver
    clock = FakeClock.new
    one = ClockAdvancingDriver.new(clock:, seconds: 2.0, name: 'one')
    two = ClockAdvancingDriver.new(clock:, seconds: 3.0, name: 'two')
    runner = Runner.new(Temporalio::Converters::ExternalStorage.new(
                          drivers: [two, one],
                          driver_selector: ->(_context, payload) { payload.data == '"a"' ? one : two },
                          payload_size_threshold: 0
                        ), namespace: nil, clock: -> { clock.now })
    originals = [payload('a'), payload('b'), payload('c')]
    original_size = originals.sum { |p| p.to_proto.bytesize }

    store_metrics = Temporalio::Internal::StorageOperationMetrics.new
    stored = runner.store(originals, metrics: store_metrics)
    retrieve_metrics = Temporalio::Internal::StorageOperationMetrics.new
    runner.retrieve(stored, metrics: retrieve_metrics)

    [store_metrics, retrieve_metrics].each do |metrics|
      proto = metrics.to_proto or flunk('Expected metrics')
      assert_equal 3, proto.payload_count
      assert_equal original_size, proto.total_size_bytes
      assert_equal %w[one two], proto.driver_names.to_a
      assert_equal 5.0, Temporalio::Internal::ProtoUtils.duration_to_seconds(proto.total_duration)
    end
  end

  def test_metrics_are_unset_when_nothing_is_moved
    runner = Runner.new(storage(InMemoryStorageDriver.new, payload_size_threshold: 1_000_000), namespace: nil)
    metrics = Temporalio::Internal::StorageOperationMetrics.new

    runner.retrieve(runner.store([payload('a')], metrics:), metrics:)

    assert_nil metrics.to_proto
  end

  def test_metrics_duration_counts_overlapping_calls_once
    metrics = Temporalio::Internal::StorageOperationMetrics.new
    metrics.record(driver_name: 'a', payload_count: 1, total_size_bytes: 1, start_time: 10.0, end_time: 12.0)
    metrics.record(driver_name: 'b', payload_count: 1, total_size_bytes: 1, start_time: 11.0, end_time: 13.0)
    metrics.record(driver_name: 'a', payload_count: 1, total_size_bytes: 1, start_time: 20.0, end_time: 20.5)

    duration = metrics.to_proto&.total_duration or flunk('Expected a duration')
    assert_equal 3.5, Temporalio::Internal::ProtoUtils.duration_to_seconds(duration)
  end

  private

  def storage(driver, payload_size_threshold: 0)
    Temporalio::Converters::ExternalStorage.new(drivers: [driver], payload_size_threshold:)
  end

  def payload(value)
    Temporalio::Api::Common::V1::Payload.new(metadata: { 'encoding' => 'json/plain' }, data: "\"#{value}\"")
  end
end
