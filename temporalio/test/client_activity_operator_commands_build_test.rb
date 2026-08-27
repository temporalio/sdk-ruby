# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client'
require 'test'

# Unit test for the operator-command request fields that the server does not surface back.
class ClientActivityOperatorCommandsBuildTest < Test
  # A server that ignores the opt-ins must not be able to make the description's has_*
  # accessors disagree with what the caller asked for. Only a stub can produce that response.
  def test_unrequested_payloads_are_stripped
    client = Temporalio::Client.connect('localhost:7233', 'test-namespace', lazy_connect: true)
    handle = client.activity_handle('act-1')

    payloads = Temporalio::Api::Common::V1::Payloads.new(
      payloads: [Temporalio::Api::Common::V1::Payload.new(
        metadata: { 'encoding' => 'json/plain' }, data: '"x"'
      )]
    )
    ws = client.workflow_service
    ws.define_singleton_method(:describe_activity_execution) do |_req, **_kwargs|
      Temporalio::Api::WorkflowService::V1::DescribeActivityExecutionResponse.new(
        info: Temporalio::Api::Activity::V1::ActivityExecutionInfo.new(
          activity_id: 'act-1',
          heartbeat_details: payloads,
          last_failure: Temporalio::Api::Failure::V1::Failure.new(message: 'boom')
        ),
        input: payloads,
        outcome: Temporalio::Api::Activity::V1::ActivityExecutionOutcome.new(result: payloads)
      )
    end

    bare = handle.describe

    refute bare.has_input?
    refute bare.has_result?
    refute bare.has_heartbeat_details?
    refute bare.has_last_failure?

    full = handle.describe(include_input: true, include_outcome: true,
                           include_heartbeat_details: true, include_last_failure: true)

    assert full.has_input?
    assert full.has_result?
    assert full.has_heartbeat_details?
    assert full.has_last_failure?

    # Stripping is per field: asking for one must not let the others through.
    one = handle.describe(include_input: true)

    assert one.has_input?
    refute one.has_result?
    refute one.has_heartbeat_details?
    refute one.has_last_failure?
  end

  # Clearing is the third state: the path is named in the mask so the server acts on it, but
  # the proto field is left unset so the value goes away rather than being set.
  def test_nil_value_clears_the_option
    client = Temporalio::Client.connect('localhost:7233', 'test-namespace', lazy_connect: true)
    handle = client.activity_handle('act-1')

    ws = client.workflow_service
    captured = {}
    ws.define_singleton_method(:update_activity_execution_options) do |req, **_kwargs|
      captured[:update] = req
      Temporalio::Api::WorkflowService::V1::UpdateActivityExecutionOptionsResponse.new(
        activity_options: Temporalio::Api::Activity::V1::ActivityOptions.new
      )
    end

    handle.update_options(heartbeat_timeout: nil, start_to_close_timeout: 90.0)

    req = captured.fetch(:update)

    assert_equal %w[heartbeat_timeout start_to_close_timeout], req.update_mask.paths.sort
    refute req.activity_options.has_heartbeat_timeout?
    assert_equal 90, req.activity_options.start_to_close_timeout.seconds
  end

  def test_unobservable_request_fields
    # Lazy connect so no real connection is opened; the RPCs below are stubbed.
    client = Temporalio::Client.connect('localhost:7233', 'test-namespace', lazy_connect: true)
    handle = client.activity_handle('act-1', activity_run_id: 'run-1')

    ws = client.workflow_service
    captured = {}

    ws.define_singleton_method(:pause_activity_execution) do |req, **_kwargs|
      captured[:pause] = req
      Temporalio::Api::WorkflowService::V1::PauseActivityExecutionResponse.new
    end
    ws.define_singleton_method(:unpause_activity_execution) do |req, **_kwargs|
      captured[:unpause] = req
      Temporalio::Api::WorkflowService::V1::UnpauseActivityExecutionResponse.new
    end
    ws.define_singleton_method(:reset_activity_execution) do |req, **_kwargs|
      captured[:reset] = req
      Temporalio::Api::WorkflowService::V1::ResetActivityExecutionResponse.new
    end
    ws.define_singleton_method(:update_activity_execution_options) do |req, **_kwargs|
      captured[:update] = req
      Temporalio::Api::WorkflowService::V1::UpdateActivityExecutionOptionsResponse.new(
        activity_options: Temporalio::Api::Activity::V1::ActivityOptions.new
      )
    end

    begin
      handle.pause('because')
      handle.unpause(reason: 'go', jitter: 5.0)
      handle.reset(jitter: 2.0, keep_paused: true, restore_original_options: true, reset_heartbeat: true)
      handle.update_options(restore_original: true)
    ensure
      ws.singleton_class.send(:remove_method, :pause_activity_execution)
      ws.singleton_class.send(:remove_method, :unpause_activity_execution)
      ws.singleton_class.send(:remove_method, :reset_activity_execution)
      ws.singleton_class.send(:remove_method, :update_activity_execution_options)
    end

    pause_req = captured.fetch(:pause)
    assert_equal 'because', pause_req.reason
    refute_empty pause_req.request_id

    unpause_req = captured.fetch(:unpause)
    assert_equal 'go', unpause_req.reason
    assert_equal 5, unpause_req.jitter.seconds
    assert_equal 0, unpause_req.jitter.nanos
    refute_empty unpause_req.request_id

    reset_req = captured.fetch(:reset)
    assert_equal 2, reset_req.jitter.seconds
    assert_equal 0, reset_req.jitter.nanos
    refute_empty reset_req.request_id
    assert reset_req.keep_paused
    assert reset_req.restore_original_options
    assert reset_req.reset_heartbeat

    update_req = captured.fetch(:update)
    refute_empty update_req.request_id
  end
end
