# frozen_string_literal: true

require 'temporalio/client/activity_id_reference'
require 'test'

class ActivityIDReferenceTest < Test
  # `.new(workflow_id:, run_id:, activity_id:)` constructs a workflow-form reference.
  def test_new_constructs_workflow_form
    ref = Temporalio::Client::ActivityIDReference.new(
      workflow_id: 'wf-1', run_id: 'r-1', activity_id: 'act-1'
    )
    assert_equal 'wf-1', ref.workflow_id
    assert_equal 'r-1', ref.run_id
    assert_equal 'act-1', ref.activity_id
    assert_nil ref.activity_run_id
    refute_predicate ref, :standalone?
  end

  def test_new_accepts_nil_run_id
    ref = Temporalio::Client::ActivityIDReference.new(
      workflow_id: 'wf-1', run_id: nil, activity_id: 'act-1'
    )
    assert_nil ref.run_id
    refute_predicate ref, :standalone?
  end

  # The standalone factory bypasses `initialize` via `allocate.tap` — verify it produces a fully-formed
  # instance with only the standalone-form fields set.
  def test_for_standalone_with_run_id
    ref = Temporalio::Client::ActivityIDReference.for_standalone(
      activity_id: 'act-1', activity_run_id: 'ar-1'
    )
    assert_equal 'act-1', ref.activity_id
    assert_equal 'ar-1', ref.activity_run_id
    assert_nil ref.workflow_id
    assert_nil ref.run_id
    assert_predicate ref, :standalone?
  end

  # `activity_run_id` is optional — nil targets "latest run" semantics.
  def test_for_standalone_without_run_id
    ref = Temporalio::Client::ActivityIDReference.for_standalone(activity_id: 'act-1')
    assert_equal 'act-1', ref.activity_id
    assert_nil ref.activity_run_id
    assert_nil ref.workflow_id
    assert_nil ref.run_id
    assert_predicate ref, :standalone?
  end

  # Both shapes must coexist on the same class without polluting each other.
  def test_two_forms_are_independent
    wf_ref = Temporalio::Client::ActivityIDReference.new(
      workflow_id: 'wf-1', run_id: 'r-1', activity_id: 'act-1'
    )
    sa_ref = Temporalio::Client::ActivityIDReference.for_standalone(
      activity_id: 'act-2', activity_run_id: 'ar-2'
    )
    # workflow-form
    assert_equal 'wf-1', wf_ref.workflow_id
    assert_nil wf_ref.activity_run_id
    # standalone-form
    assert_nil sa_ref.workflow_id
    assert_equal 'ar-2', sa_ref.activity_run_id
  end
end
