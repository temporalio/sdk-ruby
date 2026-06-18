# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client'
require 'test'

# Unit-style test that drives each operator command (pause/unpause/reset/update_options) through the
# interceptor chain against a stubbed workflow service and asserts the exact request fields built.
# No server is contacted: the client is created with a lazy connection and every operator RPC on the
# workflow service is replaced with a singleton method that captures the request and returns a canned
# response.
class ClientActivityOperatorCommandsBuildTest < Test
  def test_operator_commands_build_expected_requests
    # Lazy connect so no real connection is opened; all RPCs are stubbed below.
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
        activity_options: Temporalio::Api::Activity::V1::ActivityOptions.new(
          start_to_close_timeout: Google::Protobuf::Duration.new(seconds: 30)
        )
      )
    end

    begin
      handle.pause('because')
      handle.unpause(reason: 'go', reset_attempts: true, reset_heartbeat: true, jitter: 5.0)
      handle.reset(reset_heartbeat: true, keep_paused: true, jitter: 2.0)
      updated = handle.update_options(start_to_close_timeout: 30.0)
    ensure
      ws.singleton_class.send(:remove_method, :pause_activity_execution)
      ws.singleton_class.send(:remove_method, :unpause_activity_execution)
      ws.singleton_class.send(:remove_method, :reset_activity_execution)
      ws.singleton_class.send(:remove_method, :update_activity_execution_options)
    end

    # Each command reached the workflow service with the expected fields.
    pause_req = captured.fetch(:pause)
    assert_equal 'act-1', pause_req.activity_id
    assert_equal 'run-1', pause_req.run_id
    assert_equal 'because', pause_req.reason
    assert_equal '', pause_req.workflow_id
    refute_empty pause_req.request_id

    unpause_req = captured.fetch(:unpause)
    assert unpause_req.reset_attempts
    assert unpause_req.reset_heartbeat
    assert_equal 'go', unpause_req.reason
    assert_equal 5, unpause_req.jitter.seconds
    assert_equal 0, unpause_req.jitter.nanos

    reset_req = captured.fetch(:reset)
    assert reset_req.reset_heartbeat
    assert reset_req.keep_paused
    assert_equal 2, reset_req.jitter.seconds
    assert_equal 0, reset_req.jitter.nanos

    # A partial update mask of exactly one path proves only the provided option is sent.
    update_req = captured.fetch(:update)
    assert_equal ['start_to_close_timeout'], update_req.update_mask.paths.to_a
    assert_equal 30, update_req.activity_options.start_to_close_timeout.seconds

    # The canned response decoded back through the handle.
    assert_in_delta 30.0, updated.start_to_close_timeout, 0.001
  end
end
