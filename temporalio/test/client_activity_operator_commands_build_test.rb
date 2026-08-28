# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/client'
require 'test'

class ClientActivityOperatorCommandsBuildTest < Test
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

  def test_value_set_of_zero_sends_an_explicit_zero
    req = capture_update do |handle|
      handle.update_options(Temporalio::Client::ActivityOptions::HEARTBEAT_TIMEOUT.value_set(0))
    end

    assert_equal %w[heartbeat_timeout], req.update_mask.paths.sort
    # Present and zero, which is distinct from absent: the caller asked for zero.
    assert req.activity_options.has_heartbeat_timeout?
    assert_equal 0, req.activity_options.heartbeat_timeout.seconds
    assert_equal 0, req.activity_options.heartbeat_timeout.nanos
  end

  def test_value_unset_names_the_path_but_leaves_the_field_absent
    req = capture_update do |handle|
      handle.update_options(Temporalio::Client::ActivityOptions::HEARTBEAT_TIMEOUT.value_unset)
    end

    assert_equal %w[heartbeat_timeout], req.update_mask.paths.sort
    # Absent, which is how the server is told to clear the option.
    refute req.activity_options.has_heartbeat_timeout?
  end

  def test_mask_names_only_the_changed_options
    req = capture_update do |handle|
      handle.update_options(
        Temporalio::Client::ActivityOptions::TASK_QUEUE.value_set('new-tq'),
        Temporalio::Client::ActivityOptions::START_TO_CLOSE_TIMEOUT.value_set(90.0)
      )
    end

    assert_equal %w[start_to_close_timeout task_queue.name], req.update_mask.paths.sort
    refute req.restore_original
    assert_equal 'new-tq', req.activity_options.task_queue.name
    assert_equal 90, req.activity_options.start_to_close_timeout.seconds
  end

  def test_a_repeated_key_resolves_to_its_last_update
    req = capture_update do |handle|
      handle.update_options(
        Temporalio::Client::ActivityOptions::HEARTBEAT_TIMEOUT.value_set(5.0),
        Temporalio::Client::ActivityOptions::HEARTBEAT_TIMEOUT.value_unset
      )
    end

    # The later unset wins, and the path is named once.
    assert_equal %w[heartbeat_timeout], req.update_mask.paths.sort
    refute req.activity_options.has_heartbeat_timeout?
  end

  # Runs the block against a handle whose update RPC is stubbed, returning the captured request.
  def capture_update
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

    yield handle
    captured.fetch(:update)
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
