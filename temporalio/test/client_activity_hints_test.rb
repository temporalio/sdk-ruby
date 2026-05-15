# frozen_string_literal: true

require 'securerandom'
require 'temporalio/client'
require 'temporalio/converters/data_converter'
require 'temporalio/converters/payload_converter'
require 'temporalio/testing'
require 'temporalio/worker'
require 'test'

# Verify that hints (arg_hints, result_hint) propagate correctly through SAA paths.
# Uses a wrapping JSON payload converter that captures every hint passed to to_payload / from_payload.
class ClientActivityHintsTest < Test
  class HintTrackingJSONConverter < Temporalio::Converters::PayloadConverter::JSONPlain
    attr_accessor :outbound_hints, :inbound_hints

    def to_payload(value, hint: nil)
      (@outbound_hints ||= []) << { value:, hint: }
      super
    end

    def from_payload(payload, hint: nil)
      super.tap { |value| (@inbound_hints ||= []) << { value:, hint: } }
    end
  end

  class HintActivity < Temporalio::Activity::Definition
    activity_arg_hint :saa_arg
    activity_result_hint :saa_result

    def execute(value)
      "result-of:#{value}"
    end
  end

  def build_tracking_client
    @hint_converter = HintTrackingJSONConverter.new
    Temporalio::Client.new(**env.client.options.with(
      data_converter: Temporalio::Converters::DataConverter.new(
        payload_converter: Temporalio::Converters::PayloadConverter::Composite.new(
          *Temporalio::Converters::PayloadConverter.default.converters.values.map do |c|
            c.is_a?(Temporalio::Converters::PayloadConverter::JSONPlain) ? @hint_converter : c
          end
        )
      )
    ).to_h)
  end

  def test_activity_hints_from_definition
    client = build_tracking_client
    task_queue = "saa-hints-tq-#{SecureRandom.uuid}"
    Temporalio::Worker.new(client:, task_queue:, activities: [HintActivity]).run do
      client.execute_activity(
        HintActivity, 'hello',
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
    end
    # Definition's arg_hint (:saa_arg) used when encoding the activity arg on the client side.
    outbound = @hint_converter.outbound_hints || []
    arg_encode = outbound.find { |e| e[:value] == 'hello' }
    refute_nil arg_encode, 'Expected client to encode the activity argument'
    assert_equal :saa_arg, arg_encode[:hint], 'Client-side arg encode should use definition arg_hint'

    # Definition's result_hint (:saa_result) used when decoding the activity result on the client side.
    inbound = @hint_converter.inbound_hints || []
    result_decode = inbound.find { |e| e[:value] == 'result-of:hello' }
    refute_nil result_decode, 'Expected client to decode the activity result'
    assert_equal :saa_result, result_decode[:hint], 'Client-side result decode should use definition result_hint'
  end

  def test_activity_hints_call_site_override
    client = build_tracking_client
    task_queue = "saa-hints-tq-#{SecureRandom.uuid}"
    Temporalio::Worker.new(client:, task_queue:, activities: [HintActivity]).run do
      client.execute_activity(
        HintActivity, 'override',
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10,
        arg_hints: [:overridden_arg],
        result_hint: :overridden_result
      )
    end
    outbound = @hint_converter.outbound_hints || []
    arg_encode = outbound.find { |e| e[:value] == 'override' }
    refute_nil arg_encode
    assert_equal :overridden_arg, arg_encode[:hint],
                 'Call-site arg_hints should override definition arg_hint'

    inbound = @hint_converter.inbound_hints || []
    result_decode = inbound.find { |e| e[:value] == 'result-of:override' }
    refute_nil result_decode
    assert_equal :overridden_result, result_decode[:hint],
                 'Call-site result_hint should override definition result_hint'
  end

  def test_activity_hints_by_name_no_definition_lookup
    client = build_tracking_client
    task_queue = "saa-hints-tq-#{SecureRandom.uuid}"
    Temporalio::Worker.new(client:, task_queue:, activities: [HintActivity]).run do
      client.execute_activity(
        'HintActivity', 'by-name',
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
    end
    # By-name has no definition to read hints from; encode uses nil hint.
    outbound = @hint_converter.outbound_hints || []
    arg_encode = outbound.find { |e| e[:value] == 'by-name' }
    refute_nil arg_encode
    assert_nil arg_encode[:hint], 'By-name activity should encode with nil hint'

    inbound = @hint_converter.inbound_hints || []
    result_decode = inbound.find { |e| e[:value] == 'result-of:by-name' }
    refute_nil result_decode
    assert_nil result_decode[:hint], 'By-name activity should decode result with nil hint'
  end

  def test_activity_handle_result_hint_override
    client = build_tracking_client
    task_queue = "saa-hints-tq-#{SecureRandom.uuid}"
    Temporalio::Worker.new(client:, task_queue:, activities: [HintActivity]).run do
      handle = client.start_activity(
        HintActivity, 'override-via-result',
        id: "act-#{SecureRandom.uuid}",
        task_queue: task_queue,
        start_to_close_timeout: 10
      )
      # Override at the result()-call site instead of at start_activity time.
      handle.result(result_hint: :result_call_override)
    end
    inbound = @hint_converter.inbound_hints || []
    result_decode = inbound.find { |e| e[:value] == 'result-of:override-via-result' }
    refute_nil result_decode
    assert_equal :result_call_override, result_decode[:hint]
  end
end
