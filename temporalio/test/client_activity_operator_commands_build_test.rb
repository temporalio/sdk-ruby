# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client'
require 'test'

# Unit test for the operator-command request fields that the server does not surface back.
class ClientActivityOperatorCommandsBuildTest < Test
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
      handle.reset(jitter: 2.0)
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

    update_req = captured.fetch(:update)
    refute_empty update_req.request_id
  end
end
