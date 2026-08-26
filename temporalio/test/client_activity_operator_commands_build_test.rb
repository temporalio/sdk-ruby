# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client'
require 'test'

# Unit test for the operator-command request fields that the server does not surface back.
class ClientActivityOperatorCommandsBuildTest < Test
  # The four api#792 opt-ins are invisible in any observable server state, so only the
  # outgoing request shows whether the SDK asked for them.
  def test_describe_opt_ins_reach_the_request
    client = Temporalio::Client.connect('localhost:7233', 'test-namespace', lazy_connect: true)
    handle = client.activity_handle('act-1')

    ws = client.workflow_service
    captured = {}
    ws.define_singleton_method(:describe_activity_execution) do |req, **_kwargs|
      captured[:describe] = req
      Temporalio::Api::WorkflowService::V1::DescribeActivityExecutionResponse.new(
        info: Temporalio::Api::Activity::V1::ActivityExecutionInfo.new(activity_id: 'act-1')
      )
    end

    handle.describe
    bare = captured.fetch(:describe)

    refute bare.include_input
    refute bare.include_outcome
    refute bare.include_heartbeat_details
    refute bare.include_last_failure

    handle.describe(include_input: true, include_outcome: true,
                    include_heartbeat_details: true, include_last_failure: true)
    all = captured.fetch(:describe)

    assert all.include_input
    assert all.include_outcome
    assert all.include_heartbeat_details
    assert all.include_last_failure

    # Each flag is independent: asking for one must not set the others.
    handle.describe(include_input: true)
    one = captured.fetch(:describe)

    assert one.include_input
    refute one.include_outcome
    refute one.include_heartbeat_details
    refute one.include_last_failure
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
