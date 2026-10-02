# frozen_string_literal: true

require 'base64'
require 'base64_codec'
require 'temporalio/client'
require 'temporalio/converters/data_converter'
require 'temporalio/converters/payload_converter'
require 'temporalio/error'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'
require 'timeout'

class WorkerWorkflowEventGroupsTest < Test
  exclude_class_from_cloud :requires_cloud_provisioning,
                           'Event Groups history transcription is not yet available in Temporal Cloud.'

  ACT_TIMEOUT = 10

  class NoopActivity < Temporalio::Activity::Definition
    def execute
      nil
    end
  end

  class ControlActivity < Temporalio::Activity::Definition
    def execute(value)
      value
    end
  end

  class SleepActivity < Temporalio::Activity::Definition
    def execute
      sleep 5
    end
  end

  class FailFirstActivity < Temporalio::Activity::Definition
    def execute
      return unless Temporalio::Activity::Context.current.info.attempt == 1

      raise Temporalio::Error::ApplicationError, 'retry me'
    end
  end

  class NoopChildWorkflow < Temporalio::Workflow::Definition
    def execute
      nil
    end
  end

  class SleepChildWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.sleep(5)
    end
  end

  class WaitForSignalChildWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { @done }
    end

    workflow_signal
    def noop
      @done = true
    end
  end

  class CustomStringConverter < Temporalio::Converters::PayloadConverter::Encoding
    def encoding
      'custom'
    end

    def to_payload(value, hint: nil) # rubocop:disable Lint/UnusedMethodArgument
      return unless value.is_a?(String)

      Temporalio::Api::Common::V1::Payload.new(
        metadata: { 'encoding' => encoding },
        data: "custom-converter-#{value}".b
      )
    end

    def from_payload(payload, hint: nil) # rubocop:disable Lint/UnusedMethodArgument
      text = payload.data
      prefix = 'custom-converter-'
      text.start_with?(prefix) ? text.delete_prefix(prefix) : text
    end
  end

  def self.activity(activity_id, event_groups: nil)
    Temporalio::Workflow.execute_activity(
      NoopActivity,
      start_to_close_timeout: ACT_TIMEOUT,
      activity_id:,
      event_groups:
    )
  end

  def events_of_type(events, event_type)
    events.select { |event| event.event_type == event_type }
  end

  def single_event(events, event_type)
    matches = events_of_type(events, event_type)
    assert_equal 1, matches.size, "expected 1 #{event_type}, got #{matches.size}"
    matches.first
  end

  def activity_event(events, activity_id)
    match = events.find do |event|
      event.event_type == :EVENT_TYPE_ACTIVITY_TASK_SCHEDULED &&
        event.activity_task_scheduled_event_attributes.activity_id == activity_id
    end
    refute_nil match, "no activity #{activity_id.inspect}"
    match
  end

  def markers_named(events, marker_name)
    events.select do |event|
      event.event_type == :EVENT_TYPE_MARKER_RECORDED &&
        event.marker_recorded_event_attributes.marker_name == marker_name
    end
  end

  def signaled_event_ids(events)
    events.filter_map do |event|
      event.event_id if event.event_type == :EVENT_TYPE_WORKFLOW_EXECUTION_SIGNALED
    end
  end

  def render_marker(marker)
    case marker.variant
    when :inbound_event
      "event:#{marker.inbound_event.inbound_event_id}"
    when :inbound_update
      "update:#{marker.inbound_update.inbound_update_id}"
    else
      if marker.label.has_label?
        begin
          label = Temporalio::Converters::PayloadConverter.default.from_payload(marker.label.label)
          "label:#{marker.label.id}:#{label}"
        rescue StandardError
          "label:#{marker.label.id}"
        end
      else
        "label:#{marker.label.id}"
      end
    end
  end

  def render_marker_id(marker)
    case marker.variant
    when :inbound_event
      "event:#{marker.inbound_event.inbound_event_id}"
    when :inbound_update
      "update:#{marker.inbound_update.inbound_update_id}"
    else
      "label:#{marker.label.id}"
    end
  end

  def marker_ids(event)
    event.event_group_markers.map { |marker| render_marker_id(marker) }.sort
  end

  def assert_markers(event, *expected)
    actual = event.event_group_markers.map { |marker| render_marker(marker) }
    assert_equal expected.size, actual.size, "marker count #{actual} != #{expected}"
    assert_equal expected.sort, actual.sort
  end

  def assert_marker_ids(event, *expected)
    actual = marker_ids(event)
    assert_equal expected.size, actual.size, "marker id count #{actual} != #{expected}"
    assert_equal expected.sort, actual.sort
  end

  def label_marker(group_id, label)
    "label:#{group_id}:#{label}"
  end

  def label_marker_id(group_id)
    "label:#{group_id}"
  end

  def event_marker(event_id)
    "event:#{event_id}"
  end

  def update_marker(update_id)
    "update:#{update_id}"
  end

  def label_payload_of(event, marker_id)
    event.event_group_markers.each do |marker|
      next unless marker.variant == :label && marker.label.id == marker_id

      flunk "label marker #{marker_id.inspect} has no payload" unless marker.label.has_label?

      encoding = marker.label.label.metadata['encoding']
      return [encoding, marker.label.label.data]
    end
    flunk "no label marker #{marker_id.inspect} on event"
  end

  def label_payload_set?(event, marker_id)
    event.event_group_markers.each do |marker|
      next unless marker.variant == :label && marker.label.id == marker_id

      return marker.label.has_label?
    end
    flunk "no label marker #{marker_id.inspect} on event"
  end

  def raw_label_payload(event, marker_id)
    event.event_group_markers.each do |marker|
      next unless marker.variant == :label && marker.label.id == marker_id

      return marker.label.label
    end
    flunk "no label marker #{marker_id.inspect} on event"
  end

  def fetch_events(handle)
    handle.fetch_history_events.to_a
  end

  def run_and_events(workflow, *args, activities: [NoopActivity], more_workflows: [], **kwargs)
    execute_workflow(workflow, *args, activities:, more_workflows:, **kwargs) do |handle|
      handle.result
      yield handle, fetch_events(handle)
    end
  end

  ####################################################################################################
  # EG-LABEL-ID
  ####################################################################################################

  class UserProvidedIdsWorkflow < Temporalio::Workflow::Definition
    def execute
      c = Temporalio::Workflow.create_event_group('c-id', label: 'ccc')
      d1 = Temporalio::Workflow.create_event_group('d-id', label: 'ddd1')
      d2 = Temporalio::Workflow.create_event_group('d-id', label: 'ddd2')
      not_c = Temporalio::Workflow.create_event_group('not-c-id', label: 'ccc')
      WorkerWorkflowEventGroupsTest.activity('activity-c', event_groups: [c])
      WorkerWorkflowEventGroupsTest.activity('activity-d1', event_groups: [d1])
      WorkerWorkflowEventGroupsTest.activity('activity-d2', event_groups: [d2])
      WorkerWorkflowEventGroupsTest.activity('activity-not-c', event_groups: [not_c])
    end
  end

  def test_user_provided_label_ids
    run_and_events(UserProvidedIdsWorkflow) do |_handle, events|
      assert_equal 4, events_of_type(events, :EVENT_TYPE_ACTIVITY_TASK_SCHEDULED).size
      assert_marker_ids(activity_event(events, 'activity-c'), label_marker_id('c-id'))
      assert_equal marker_ids(activity_event(events, 'activity-d1')),
                   marker_ids(activity_event(events, 'activity-d2'))
      refute_equal marker_ids(activity_event(events, 'activity-c')),
                   marker_ids(activity_event(events, 'activity-not-c'))
    end
  end

  ####################################################################################################
  # EG-LABEL-PAYLOAD
  ####################################################################################################

  class LabelPayloadWorkflow < Temporalio::Workflow::Definition
    def execute
      a = Temporalio::Workflow.create_event_group('aaa')
      b = Temporalio::Workflow.create_event_group('bbb', label: 'Label B')
      Temporalio::Workflow.execute_activity(
        ControlActivity, 'control', start_to_close_timeout: ACT_TIMEOUT, activity_id: 'control'
      )
      WorkerWorkflowEventGroupsTest.activity('activity-a', event_groups: [a])
      WorkerWorkflowEventGroupsTest.activity('activity-b', event_groups: [b])
    end
  end

  def test_label_payload_is_json_plain
    run_and_events(LabelPayloadWorkflow, activities: [NoopActivity, ControlActivity]) do |_handle, events|
      activity_a = activity_event(events, 'activity-a')
      activity_b = activity_event(events, 'activity-b')
      assert_markers(activity_a, label_marker_id('aaa'))
      assert_markers(activity_b, label_marker('bbb', 'Label B'))
      assert_equal ['json/plain', '"Label B"'], label_payload_of(activity_b, 'bbb')
      refute label_payload_set?(activity_a, 'aaa')
    end
  end

  def test_label_payload_uses_default_converter_not_worker_converter
    payload_converter = Temporalio::Converters::PayloadConverter::Composite.new(
      CustomStringConverter.new,
      *Temporalio::Converters::PayloadConverter.new_with_defaults.converters.values
    )
    client = Temporalio::Client.new(
      **env.client.options.with(data_converter: Temporalio::Converters::DataConverter.new(payload_converter:)).to_h
    )
    run_and_events(LabelPayloadWorkflow, activities: [NoopActivity, ControlActivity], client:) do |_handle, events|
      control = activity_event(events, 'control')
      control_payload = control.activity_task_scheduled_event_attributes.input.payloads.first
      assert_equal 'custom', control_payload.metadata['encoding']
      assert_equal 'custom-converter-control', control_payload.data

      activity_a = activity_event(events, 'activity-a')
      activity_b = activity_event(events, 'activity-b')
      assert_equal ['json/plain', '"Label B"'], label_payload_of(activity_b, 'bbb')
      refute label_payload_set?(activity_a, 'aaa')
    end
  end

  def test_label_payload_is_codec_encoded_but_ids_are_not
    codec = Base64Codec.new
    client = Temporalio::Client.new(
      **env.client.options.with(data_converter: Temporalio::Converters::DataConverter.new(payload_codec: codec)).to_h
    )
    run_and_events(
      LabelPayloadWorkflow,
      activities: [NoopActivity, ControlActivity],
      client:,
      workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default
    ) do |_handle, events|
      activity_a = activity_event(events, 'activity-a')
      activity_b = activity_event(events, 'activity-b')
      assert_marker_ids(activity_a, label_marker_id('aaa'))
      assert_marker_ids(activity_b, label_marker_id('bbb'))
      assert_equal 'test/base64', label_payload_of(activity_b, 'bbb').first
      decoded = codec.decode([raw_label_payload(activity_b, 'bbb')]).first
      assert_equal 'Label B', Temporalio::Converters::PayloadConverter.default.from_payload(decoded)
      refute label_payload_set?(activity_a, 'aaa')
    end
  end

  ####################################################################################################
  # EG-SCOPE
  ####################################################################################################

  class ScopeBaselineWorkflow < Temporalio::Workflow::Definition
    def execute
      a = Temporalio::Workflow.create_event_group('aaa')
      Temporalio::Workflow.with_event_groups(a) do
        WorkerWorkflowEventGroupsTest.activity('activity')
        Temporalio::Workflow.sleep(0.001)
        Temporalio::Workflow.start_child_workflow(
          NoopChildWorkflow, id: "#{Temporalio::Workflow.info.workflow_id}_child"
        )
      end
    end
  end

  def test_commands_in_a_scope_carry_its_marker
    run_and_events(ScopeBaselineWorkflow, more_workflows: [NoopChildWorkflow]) do |_handle, events|
      a = label_marker_id('aaa')
      assert_markers(activity_event(events, 'activity'), a)
      assert_markers(single_event(events, :EVENT_TYPE_TIMER_STARTED), a)
      assert_markers(single_event(events, :EVENT_TYPE_START_CHILD_WORKFLOW_EXECUTION_INITIATED), a)
    end
  end

  class NestedScopesWorkflow < Temporalio::Workflow::Definition
    def execute
      a = Temporalio::Workflow.create_event_group('aaa')
      b = Temporalio::Workflow.create_event_group('bbb')
      Temporalio::Workflow.with_event_groups(a) do
        WorkerWorkflowEventGroupsTest.activity('a-before')
        Temporalio::Workflow.with_event_groups(b) { WorkerWorkflowEventGroupsTest.activity('a-b') }
        WorkerWorkflowEventGroupsTest.activity('a-after')
      end
      WorkerWorkflowEventGroupsTest.activity('outside')
    end
  end

  def test_nesting_scopes_composes
    run_and_events(NestedScopesWorkflow) do |_handle, events|
      a = label_marker_id('aaa')
      b = label_marker_id('bbb')
      assert_equal 4, events_of_type(events, :EVENT_TYPE_ACTIVITY_TASK_SCHEDULED).size
      assert_markers(activity_event(events, 'a-before'), a)
      assert_markers(activity_event(events, 'a-b'), a, b)
      assert_markers(activity_event(events, 'a-after'), a)
      assert_markers(activity_event(events, 'outside'))
    end
  end

  class ReenteredScopeWorkflow < Temporalio::Workflow::Definition
    def execute
      a = Temporalio::Workflow.create_event_group('aaa')
      Temporalio::Workflow.with_event_groups(a) do
        WorkerWorkflowEventGroupsTest.activity('a-before')
        Temporalio::Workflow.with_event_groups(a) { WorkerWorkflowEventGroupsTest.activity('a-a') }
        WorkerWorkflowEventGroupsTest.activity('a-after')
      end
    end
  end

  def test_reentering_a_group_nests_correctly
    run_and_events(ReenteredScopeWorkflow) do |_handle, events|
      a = label_marker_id('aaa')
      assert_markers(activity_event(events, 'a-before'), a)
      assert_markers(activity_event(events, 'a-a'), a)
      assert_markers(activity_event(events, 'a-after'), a)
    end
  end

  class ConcurrentScopesWorkflow < Temporalio::Workflow::Definition
    def execute
      a = Temporalio::Workflow.create_event_group('aaa')
      b = Temporalio::Workflow.create_event_group('bbb')
      c = Temporalio::Workflow.create_event_group('ccc')
      d = Temporalio::Workflow.create_event_group('ddd')
      e = Temporalio::Workflow.create_event_group('eee')

      left = Temporalio::Workflow::Future.new do
        Temporalio::Workflow.with_event_groups(b) do
          Temporalio::Workflow.with_event_groups(a) do
            Temporalio::Workflow.with_event_groups(c) { WorkerWorkflowEventGroupsTest.activity('b-a-c') }
            WorkerWorkflowEventGroupsTest.activity('b-a')
          end
          WorkerWorkflowEventGroupsTest.activity('b-after-a')
        end
      end
      right = Temporalio::Workflow::Future.new do
        Temporalio::Workflow.with_event_groups(d) do
          Temporalio::Workflow.with_event_groups(a) do
            Temporalio::Workflow.with_event_groups(e) { WorkerWorkflowEventGroupsTest.activity('d-a-e') }
            WorkerWorkflowEventGroupsTest.activity('d-a')
          end
          WorkerWorkflowEventGroupsTest.activity('d-after-a')
        end
      end
      left.wait
      right.wait
      WorkerWorkflowEventGroupsTest.activity('outside')
    end
  end

  def test_a_group_can_be_scoped_from_two_concurrent_branches
    run_and_events(ConcurrentScopesWorkflow) do |_handle, events|
      a = label_marker_id('aaa')
      b = label_marker_id('bbb')
      c = label_marker_id('ccc')
      d = label_marker_id('ddd')
      e = label_marker_id('eee')
      assert_equal 7, events_of_type(events, :EVENT_TYPE_ACTIVITY_TASK_SCHEDULED).size
      assert_markers(activity_event(events, 'b-a-c'), b, a, c)
      assert_markers(activity_event(events, 'b-a'), b, a)
      assert_markers(activity_event(events, 'b-after-a'), b)
      assert_markers(activity_event(events, 'd-a-e'), d, a, e)
      assert_markers(activity_event(events, 'd-a'), d, a)
      assert_markers(activity_event(events, 'd-after-a'), d)
      assert_markers(activity_event(events, 'outside'))
    end
  end

  class DetachedTaskScopeWorkflow < Temporalio::Workflow::Definition
    def execute
      a = Temporalio::Workflow.create_event_group('aaa')
      # @type var fut: Temporalio::Workflow::Future[untyped]
      fut = Temporalio::Workflow.with_event_groups(a) do
        started = Temporalio::Workflow::Future.new do
          WorkerWorkflowEventGroupsTest.activity('inside-before')
          @started = true
          Temporalio::Workflow.wait_condition { @released }
          WorkerWorkflowEventGroupsTest.activity('inside-after')
        end
        Temporalio::Workflow.wait_condition { @started }
        started
      end
      WorkerWorkflowEventGroupsTest.activity('outside-after-scope')
      @released = true
      fut.wait
    end
  end

  def test_a_task_started_inside_a_scope_keeps_it_after_exit
    run_and_events(DetachedTaskScopeWorkflow) do |_handle, events|
      a = label_marker_id('aaa')
      assert_markers(activity_event(events, 'inside-before'), a)
      assert_markers(activity_event(events, 'inside-after'), a)
      assert_markers(activity_event(events, 'outside-after-scope'))
    end
  end

  class OutsiderTaskScopeWorkflow < Temporalio::Workflow::Definition
    def execute
      a = Temporalio::Workflow.create_event_group('aaa')
      fut = Temporalio::Workflow::Future.new do
        Temporalio::Workflow.wait_condition { @started }
        WorkerWorkflowEventGroupsTest.activity('outside-task')
      end
      Temporalio::Workflow.with_event_groups(a) do
        @started = true
        WorkerWorkflowEventGroupsTest.activity('in-a')
        fut.wait
      end
    end
  end

  def test_a_task_created_outside_a_scope_does_not_inherit_it
    run_and_events(OutsiderTaskScopeWorkflow) do |_handle, events|
      assert_markers(activity_event(events, 'in-a'), label_marker_id('aaa'))
      assert_markers(activity_event(events, 'outside-task'))
    end
  end

  class ThrowingScopeWorkflow < Temporalio::Workflow::Definition
    def execute
      a = Temporalio::Workflow.create_event_group('aaa')
      b = Temporalio::Workflow.create_event_group('bbb')
      Temporalio::Workflow.with_event_groups(a) do
        begin
          Temporalio::Workflow.with_event_groups(b) do
            WorkerWorkflowEventGroupsTest.activity('a-b')
            raise 'boom'
          end
        rescue RuntimeError
          nil
        end
        WorkerWorkflowEventGroupsTest.activity('a-after')
      end
    end
  end

  def test_a_scope_unwinds_cleanly_when_its_body_throws
    run_and_events(ThrowingScopeWorkflow) do |_handle, events|
      a = label_marker_id('aaa')
      b = label_marker_id('bbb')
      assert_equal 2, events_of_type(events, :EVENT_TYPE_ACTIVITY_TASK_SCHEDULED).size
      assert_markers(activity_event(events, 'a-b'), a, b)
      assert_markers(activity_event(events, 'a-after'), a)
    end
  end

  ####################################################################################################
  # EG-IMPLICIT
  ####################################################################################################

  def test_invalid_inbound_event_id_is_noop_stub
    stub = Temporalio::Workflow._inbound_event_group(0)
    assert_instance_of Temporalio::Workflow::EventGroup::StubImplicit, stub
    assert_instance_of Temporalio::Workflow::EventGroup::StubImplicit, Temporalio::Workflow._inbound_event_group(-1)

    enclosing = Temporalio::Workflow::EventGroup::Active.new(
      implicit: nil,
      explicit: { 'id' => Temporalio::Workflow::EventGroup::Label.new('id', 'label') }
    )
    applied = stub._applied_over(enclosing)
    assert_nil applied.implicit
    assert_empty applied.explicit

    prev = Fiber[Temporalio::Workflow::EventGroup::STORAGE_KEY]
    Fiber[Temporalio::Workflow::EventGroup::STORAGE_KEY] = applied
    begin
      assert_empty Temporalio::Workflow::EventGroup._markers_for_command(nil)
    ensure
      Fiber[Temporalio::Workflow::EventGroup::STORAGE_KEY] = prev
    end
  end

  class StaticSignalHandlerWorkflow < Temporalio::Workflow::Definition
    def execute
      WorkerWorkflowEventGroupsTest.activity('from-main-before-signal')
      Temporalio::Workflow.wait_condition { @done }
      WorkerWorkflowEventGroupsTest.activity('from-main-after-signal')
    end

    workflow_signal
    def my_signal
      WorkerWorkflowEventGroupsTest.activity('from-static-signal')
      a = Temporalio::Workflow.create_event_group('aaa')
      Temporalio::Workflow.with_event_groups(a) { WorkerWorkflowEventGroupsTest.activity('from-static-signal-scoped') }
      @done = true
    end
  end

  def test_static_signal_handler_implicit_group
    execute_workflow(StaticSignalHandlerWorkflow, activities: [NoopActivity]) do |handle|
      handle.signal(StaticSignalHandlerWorkflow.my_signal)
      handle.result
      events = fetch_events(handle)
      signal = event_marker(signaled_event_ids(events).first)
      a = label_marker_id('aaa')
      assert_markers(activity_event(events, 'from-static-signal'), signal)
      assert_markers(activity_event(events, 'from-static-signal-scoped'), signal, a)
      assert_markers(activity_event(events, 'from-main-before-signal'))
      assert_markers(activity_event(events, 'from-main-after-signal'))
    end
  end

  class RuntimeSignalHandlerWorkflow < Temporalio::Workflow::Definition
    def execute
      outside = Temporalio::Workflow.create_event_group('outside')
      inside = Temporalio::Workflow.create_event_group('inside')
      Temporalio::Workflow.with_event_groups(outside) do
        Temporalio::Workflow.signal_handlers['mySignal'] = Temporalio::Workflow::Definition::Signal.new(
          name: 'mySignal',
          to_invoke: proc do
            WorkerWorkflowEventGroupsTest.activity('from-runtime-signal')
            Temporalio::Workflow.with_event_groups(inside) do
              WorkerWorkflowEventGroupsTest.activity('from-runtime-signal-scoped')
            end
            @done = true
          end
        )
        WorkerWorkflowEventGroupsTest.activity('in-outside')
      end
      WorkerWorkflowEventGroupsTest.activity('from-main-before-signal')
      Temporalio::Workflow.wait_condition { @done }
      WorkerWorkflowEventGroupsTest.activity('from-main-after-signal')
    end
  end

  def test_runtime_signal_handler_implicit_group
    execute_workflow(RuntimeSignalHandlerWorkflow, activities: [NoopActivity]) do |handle|
      handle.signal(:mySignal)
      handle.result
      events = fetch_events(handle)
      signal_ids = signaled_event_ids(events)
      assert_equal 1, signal_ids.size
      signal = event_marker(signal_ids.first)
      outside = label_marker_id('outside')
      inside = label_marker_id('inside')
      assert_markers(activity_event(events, 'from-runtime-signal'), signal)
      assert_markers(activity_event(events, 'in-outside'), outside)
      assert_markers(activity_event(events, 'from-runtime-signal-scoped'), signal, inside)
      assert_markers(activity_event(events, 'from-main-before-signal'))
      assert_markers(activity_event(events, 'from-main-after-signal'))
    end
  end

  class BufferedSignalWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.signal_handlers['unblock'] = Temporalio::Workflow::Definition::Signal.new(
        name: 'unblock',
        to_invoke: proc { @unblocked = true }
      )
      Temporalio::Workflow.wait_condition { @unblocked }
      Temporalio::Workflow.signal_handlers['mySignal'] = Temporalio::Workflow::Definition::Signal.new(
        name: 'mySignal',
        to_invoke: proc do
          WorkerWorkflowEventGroupsTest.activity('from-runtime-signal')
          @handled = true
        end
      )
      Temporalio::Workflow.wait_condition { @handled }
    end
  end

  def test_buffered_signal_keeps_its_original_implicit_marker
    execute_workflow(BufferedSignalWorkflow, activities: [NoopActivity]) do |handle|
      handle.signal(:mySignal)
      handle.signal(:unblock)
      handle.result
      events = fetch_events(handle)
      my_signal = events.find do |event|
        event.event_type == :EVENT_TYPE_WORKFLOW_EXECUTION_SIGNALED &&
          event.workflow_execution_signaled_event_attributes.signal_name == 'mySignal'
      end
      assert_markers(activity_event(events, 'from-runtime-signal'), event_marker(my_signal.event_id))
    end
  end

  class CatchAllSignalWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { @done }
    end

    workflow_signal dynamic: true
    def catch_all(_name)
      WorkerWorkflowEventGroupsTest.activity('from-catch-all-signal')
      @done = true
    end
  end

  def test_catch_all_signal_handler_implicit_group
    execute_workflow(CatchAllSignalWorkflow, activities: [NoopActivity]) do |handle|
      handle.signal(:unknownSignal)
      handle.result
      events = fetch_events(handle)
      assert_markers(activity_event(events, 'from-catch-all-signal'), event_marker(signaled_event_ids(events).first))
    end
  end

  class StaticUpdateHandlerWorkflow < Temporalio::Workflow::Definition
    def execute
      WorkerWorkflowEventGroupsTest.activity('from-main-before-update')
      Temporalio::Workflow.wait_condition { @done }
      WorkerWorkflowEventGroupsTest.activity('from-main-after-update')
    end

    workflow_update
    def my_update
      WorkerWorkflowEventGroupsTest.activity('from-static-update')
      inside = Temporalio::Workflow.create_event_group('inside')
      Temporalio::Workflow.with_event_groups(inside) do
        WorkerWorkflowEventGroupsTest.activity('from-static-update-scoped')
      end
      @done = true
    end
  end

  def test_static_update_handler_implicit_group
    update_id = 'static-update-1'
    execute_workflow(StaticUpdateHandlerWorkflow, activities: [NoopActivity]) do |handle|
      handle.execute_update(StaticUpdateHandlerWorkflow.my_update, id: update_id)
      handle.result
      events = fetch_events(handle)
      update = update_marker(update_id)
      inside = label_marker_id('inside')
      assert_markers(activity_event(events, 'from-static-update'), update)
      assert_markers(activity_event(events, 'from-static-update-scoped'), update, inside)
      assert_markers(activity_event(events, 'from-main-before-update'))
      assert_markers(activity_event(events, 'from-main-after-update'))
    end
  end

  class RuntimeUpdateHandlerWorkflow < Temporalio::Workflow::Definition
    def execute
      outside = Temporalio::Workflow.create_event_group('outside')
      inside = Temporalio::Workflow.create_event_group('inside')
      Temporalio::Workflow.with_event_groups(outside) do
        Temporalio::Workflow.update_handlers['myUpdate'] = Temporalio::Workflow::Definition::Update.new(
          name: 'myUpdate',
          to_invoke: proc do
            WorkerWorkflowEventGroupsTest.activity('from-runtime-update')
            Temporalio::Workflow.with_event_groups(inside) do
              WorkerWorkflowEventGroupsTest.activity('from-runtime-update-scoped')
            end
            @done = true
          end
        )
        WorkerWorkflowEventGroupsTest.activity('in-outside')
      end
      WorkerWorkflowEventGroupsTest.activity('from-main-before-update')
      Temporalio::Workflow.wait_condition { @done }
      WorkerWorkflowEventGroupsTest.activity('from-main-after-update')
    end
  end

  def test_runtime_update_handler_implicit_group
    update_id = 'runtime-update-1'
    execute_workflow(RuntimeUpdateHandlerWorkflow, activities: [NoopActivity]) do |handle|
      # Updates that arrive before registration are rejected, not buffered.
      assert_eventually { activity_event(fetch_events(handle), 'in-outside') }
      handle.execute_update(:myUpdate, id: update_id)
      handle.result
      events = fetch_events(handle)
      update = update_marker(update_id)
      outside = label_marker_id('outside')
      inside = label_marker_id('inside')
      assert_markers(activity_event(events, 'from-runtime-update'), update)
      assert_markers(activity_event(events, 'in-outside'), outside)
      assert_markers(activity_event(events, 'from-runtime-update-scoped'), update, inside)
      assert_markers(activity_event(events, 'from-main-before-update'))
      assert_markers(activity_event(events, 'from-main-after-update'))
    end
  end

  class CatchAllUpdateWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { @done }
    end

    workflow_update dynamic: true
    def catch_all(_name)
      WorkerWorkflowEventGroupsTest.activity('from-catch-all-update')
      @done = true
    end
  end

  def test_catch_all_update_handler_implicit_group
    update_id = 'catch-all-update-1'
    execute_workflow(CatchAllUpdateWorkflow, activities: [NoopActivity]) do |handle|
      handle.execute_update(:unknownUpdate, id: update_id)
      handle.result
      events = fetch_events(handle)
      assert_markers(activity_event(events, 'from-catch-all-update'), update_marker(update_id))
    end
  end

  ####################################################################################################
  # EG-AGGREGATION
  ####################################################################################################

  class AggregationWorkflow < Temporalio::Workflow::Definition
    def execute
      a1 = Temporalio::Workflow.create_event_group('aaa')
      a2 = Temporalio::Workflow.create_event_group('aaa')
      b1 = Temporalio::Workflow.create_event_group('b-id', label: 'bbb1')
      b2 = Temporalio::Workflow.create_event_group('b-id', label: 'bbb2')
      WorkerWorkflowEventGroupsTest.activity('direct-duplicates', event_groups: [a2, b1, a1, b1, a2, a1])
      Temporalio::Workflow.with_event_groups(a1) do
        Temporalio::Workflow.with_event_groups(a2) do
          Temporalio::Workflow.with_event_groups(b1) { WorkerWorkflowEventGroupsTest.activity('nested-scopes') }
        end
      end
      Temporalio::Workflow.with_event_groups(a1) do
        Temporalio::Workflow.with_event_groups(b1) do
          WorkerWorkflowEventGroupsTest.activity('scope-and-direct-b', event_groups: [b1])
          WorkerWorkflowEventGroupsTest.activity('scope-and-direct-a-b', event_groups: [b1, a1])
        end
      end
      WorkerWorkflowEventGroupsTest.activity('same-instance-twice', event_groups: [a1, a1])
      WorkerWorkflowEventGroupsTest.activity('same-id-direct', event_groups: [b1, b2])
      Temporalio::Workflow.with_event_groups(b1) do
        WorkerWorkflowEventGroupsTest.activity('same-id-scope-and-direct', event_groups: [b2])
      end
    end
  end

  def test_markers_dedupe_by_id
    run_and_events(AggregationWorkflow) do |_handle, events|
      a = label_marker_id('aaa')
      b = label_marker('b-id', 'bbb1')
      both = [a, b]
      assert_markers(activity_event(events, 'direct-duplicates'), *both)
      assert_markers(activity_event(events, 'nested-scopes'), *both)
      assert_markers(activity_event(events, 'scope-and-direct-b'), *both)
      assert_markers(activity_event(events, 'scope-and-direct-a-b'), *both)
      assert_markers(activity_event(events, 'same-instance-twice'), a)
      assert_marker_ids(activity_event(events, 'same-id-direct'), label_marker_id('b-id'))
      assert_marker_ids(activity_event(events, 'same-id-scope-and-direct'), label_marker_id('b-id'))
    end
  end

  ####################################################################################################
  # EG-COMMANDS
  ####################################################################################################

  class TimerCommandsWorkflow < Temporalio::Workflow::Definition
    def execute
      direct = Temporalio::Workflow.create_event_group('direct')
      scope = Temporalio::Workflow.create_event_group('scope')
      Temporalio::Workflow.with_event_groups(scope) do
        Temporalio::Workflow.sleep(0.001, event_groups: [direct])
        begin
          Temporalio::Workflow.timeout(0.001, event_groups: [direct]) { Temporalio::Workflow.wait_condition { false } }
        rescue Timeout::Error
          nil
        end
        cancel, cancel_proc = Temporalio::Cancellation.new
        long = Temporalio::Workflow::Future.new do
          Temporalio::Workflow.sleep(60, cancellation: cancel, event_groups: [direct])
        end
        Temporalio::Workflow.sleep(0.001)
        cancel_proc.call
        begin
          long.wait
        rescue Temporalio::Error::CanceledError
          nil
        end
      end
    end
  end

  def test_timer_commands_carry_markers
    run_and_events(TimerCommandsWorkflow, activities: []) do |_handle, events|
      both = [label_marker_id('direct'), label_marker_id('scope')]
      ambient = [label_marker_id('scope')]
      timers = events_of_type(events, :EVENT_TYPE_TIMER_STARTED)
      assert_equal 4, timers.size
      cancels = events_of_type(events, :EVENT_TYPE_TIMER_CANCELED)
      assert_equal 1, cancels.size
      assert_markers(timers[0], *both)
      assert_markers(timers[1], *both)
      rest = timers.drop(2)
      ambient_timers = rest.select { |timer| timer.event_group_markers.map { render_marker(_1) }.sort == ambient.sort }
      both_timers = rest.select { |timer| timer.event_group_markers.map { render_marker(_1) }.sort == both.sort }
      assert_equal 1, ambient_timers.size
      assert_equal 1, both_timers.size
      assert_markers(cancels[0], *both)
    end
  end

  class ActivityCommandsWorkflow < Temporalio::Workflow::Definition
    def execute
      direct = Temporalio::Workflow.create_event_group('direct')
      scope = Temporalio::Workflow.create_event_group('scope')
      Temporalio::Workflow.with_event_groups(scope) do
        Temporalio::Workflow.execute_activity(
          NoopActivity,
          start_to_close_timeout: ACT_TIMEOUT,
          schedule_to_start_timeout: 10,
          event_groups: [direct],
          activity_id: 'activity'
        )
        cancel, cancel_proc = Temporalio::Cancellation.new
        fut = Temporalio::Workflow::Future.new do
          Temporalio::Workflow.execute_activity(
            SleepActivity,
            start_to_close_timeout: ACT_TIMEOUT,
            schedule_to_start_timeout: 10,
            cancellation: cancel,
            cancellation_type: Temporalio::Workflow::ActivityCancellationType::TRY_CANCEL,
            event_groups: [direct],
            activity_id: 'activity-cancelled-sleep-5s'
          )
        end
        Temporalio::Workflow.sleep(0.001)
        cancel_proc.call
        begin
          fut.wait
        rescue Temporalio::Error::ActivityError, Temporalio::Error::CanceledError
          nil
        end
      end
    end
  end

  def test_activity_commands_carry_markers
    run_and_events(ActivityCommandsWorkflow, activities: [NoopActivity, SleepActivity]) do |_handle, events|
      both = [label_marker_id('direct'), label_marker_id('scope')]
      assert_markers(activity_event(events, 'activity'), *both)
      assert_markers(activity_event(events, 'activity-cancelled-sleep-5s'), *both)
      assert_markers(single_event(events, :EVENT_TYPE_ACTIVITY_TASK_CANCEL_REQUESTED), *both)
    end
  end

  class LocalActivityCommandsWorkflow < Temporalio::Workflow::Definition
    def execute
      direct = Temporalio::Workflow.create_event_group('direct')
      scope = Temporalio::Workflow.create_event_group('scope')
      Temporalio::Workflow.with_event_groups(scope) do
        Temporalio::Workflow.execute_local_activity(
          NoopActivity,
          start_to_close_timeout: ACT_TIMEOUT,
          event_groups: [direct],
          activity_id: 'local-activity'
        )

        cancel_trigger = Temporalio::Workflow.create_event_group('cancel-trigger')
        cancelled_la = Temporalio::Workflow.create_event_group('cancelled-la')
        cancel, cancel_proc = Temporalio::Cancellation.new
        sleeping = Temporalio::Workflow::Future.new do
          Temporalio::Workflow.execute_local_activity(
            SleepActivity,
            start_to_close_timeout: ACT_TIMEOUT,
            cancellation: cancel,
            cancellation_type: Temporalio::Workflow::ActivityCancellationType::TRY_CANCEL,
            event_groups: [direct, cancelled_la],
            activity_id: 'cancelled-local-activity-sleep-5s'
          )
        end
        trigger = Temporalio::Workflow::Future.new do
          Temporalio::Workflow.execute_local_activity(
            NoopActivity,
            start_to_close_timeout: ACT_TIMEOUT,
            event_groups: [direct, cancel_trigger],
            activity_id: 'cancel-trigger'
          )
          cancel_proc.call
        end
        begin
          sleeping.wait
        rescue Temporalio::Error::ActivityError, Temporalio::Error::CanceledError
          nil
        end
        trigger.wait

        Temporalio::Workflow.execute_local_activity(
          FailFirstActivity,
          start_to_close_timeout: ACT_TIMEOUT,
          local_retry_threshold: 0.001,
          retry_policy: Temporalio::RetryPolicy.new(initial_interval: 1, backoff_coefficient: 1, max_attempts: 2),
          event_groups: [direct],
          activity_id: 'backoff-local-activity-fail-first-attempt'
        )
      end
    end
  end

  def test_local_activity_commands_carry_markers
    execute_workflow(
      LocalActivityCommandsWorkflow,
      activities: [NoopActivity, SleepActivity, FailFirstActivity],
      task_timeout: 5
    ) do |handle|
      handle.result
      events = fetch_events(handle)
      both = [label_marker_id('direct'), label_marker_id('scope')]
      cancel_trigger = [*both, label_marker_id('cancel-trigger')]
      cancelled_la = [*both, label_marker_id('cancelled-la')]
      local_acts = markers_named(events, 'core_local_activity')
      assert_equal 5, local_acts.size
      assert_markers(local_acts[0], *both)
      assert_markers(local_acts[1], *cancel_trigger)
      assert_markers(local_acts[2], *cancelled_la)
      backoff_timer = events_of_type(events, :EVENT_TYPE_TIMER_STARTED)
      assert_equal 1, backoff_timer.size
      assert_markers(backoff_timer[0], *both)
      assert_markers(local_acts[3], *both)
      assert_markers(local_acts[4], *both)
    end
  end

  class ChildWorkflowCommandsWorkflow < Temporalio::Workflow::Definition
    def execute
      direct = Temporalio::Workflow.create_event_group('direct')
      scope = Temporalio::Workflow.create_event_group('scope')
      Temporalio::Workflow.with_event_groups(scope) do
        Temporalio::Workflow.start_child_workflow(
          NoopChildWorkflow,
          id: "#{Temporalio::Workflow.info.workflow_id}_child",
          event_groups: [direct]
        )
        cancel, cancel_proc = Temporalio::Cancellation.new
        fut = Temporalio::Workflow::Future.new do
          Temporalio::Workflow.execute_child_workflow(
            SleepChildWorkflow,
            id: "#{Temporalio::Workflow.info.workflow_id}_child_cancel",
            cancellation: cancel,
            cancellation_type: Temporalio::Workflow::ChildWorkflowCancellationType::WAIT_CANCELLATION_REQUESTED,
            event_groups: [direct]
          )
        end
        Temporalio::Workflow.sleep(0.001)
        cancel_proc.call
        begin
          fut.wait
        rescue Temporalio::Error::ChildWorkflowError, Temporalio::Error::CanceledError
          nil
        end
      end
    end
  end

  def test_child_workflow_commands_carry_markers
    run_and_events(
      ChildWorkflowCommandsWorkflow,
      activities: [],
      more_workflows: [NoopChildWorkflow, SleepChildWorkflow]
    ) do |_handle, events|
      both = [label_marker_id('direct'), label_marker_id('scope')]
      initiated = events_of_type(events, :EVENT_TYPE_START_CHILD_WORKFLOW_EXECUTION_INITIATED)
      assert_equal 2, initiated.size
      assert_markers(initiated[0], *both)
      assert_markers(initiated[1], *both)
      assert_markers(single_event(events, :EVENT_TYPE_REQUEST_CANCEL_EXTERNAL_WORKFLOW_EXECUTION_INITIATED), *both)
    end
  end

  class NexusCommandsWorkflow < Temporalio::Workflow::Definition
    def execute(endpoint)
      direct = Temporalio::Workflow.create_event_group('direct')
      scope = Temporalio::Workflow.create_event_group('scope')
      client = Temporalio::Workflow.create_nexus_client(endpoint:, service: 'test-service')
      Temporalio::Workflow.with_event_groups(scope) do
        client.execute_operation('echo', 'success', event_groups: [direct])
        cancel, cancel_proc = Temporalio::Cancellation.new
        running = Temporalio::Workflow::Future.new do
          client.execute_operation(
            'workflow-operation',
            { 'action' => 'wait-for-cancel' },
            cancellation: cancel,
            cancellation_type: Temporalio::Workflow::NexusOperationCancellationType::TRY_CANCEL,
            event_groups: [direct]
          )
        end
        Temporalio::Workflow.sleep(0.001)
        cancel_proc.call
        begin
          running.wait
        rescue Temporalio::Error::NexusOperationError, Temporalio::Error::CanceledError
          nil
        end
      end
    end
  end

  def test_nexus_operation_commands_carry_markers
    env.with_kitchen_sink_worker(nexus: true) do |task_queue|
      endpoint = "nexus-endpoint-#{task_queue}"
      run_and_events(NexusCommandsWorkflow, endpoint, activities: []) do |_handle, events|
        both = [label_marker_id('direct'), label_marker_id('scope')]
        scheduled = events_of_type(events, :EVENT_TYPE_NEXUS_OPERATION_SCHEDULED)
        assert_equal 2, scheduled.size
        assert_markers(scheduled[0], *both)
        assert_markers(scheduled[1], *both)
        assert_markers(single_event(events, :EVENT_TYPE_NEXUS_OPERATION_CANCEL_REQUESTED), *both)
      end
    end
  end

  class ExternalWorkflowCommandsWorkflow < Temporalio::Workflow::Definition
    def execute
      direct = Temporalio::Workflow.create_event_group('direct')
      scope = Temporalio::Workflow.create_event_group('scope')
      missing = Temporalio::Workflow.external_workflow_handle('event-groups-no-such-workflow')
      Temporalio::Workflow.with_event_groups(scope) do
        begin
          missing.signal('signal', event_groups: [direct])
        rescue Temporalio::Error
          nil
        end
        begin
          missing.cancel(event_groups: [direct])
        rescue Temporalio::Error
          nil
        end
      end
    end
  end

  def test_external_workflow_commands_carry_markers
    run_and_events(ExternalWorkflowCommandsWorkflow, activities: []) do |_handle, events|
      both = [label_marker_id('direct'), label_marker_id('scope')]
      assert_markers(single_event(events, :EVENT_TYPE_SIGNAL_EXTERNAL_WORKFLOW_EXECUTION_INITIATED), *both)
      assert_markers(single_event(events, :EVENT_TYPE_REQUEST_CANCEL_EXTERNAL_WORKFLOW_EXECUTION_INITIATED), *both)
    end
  end

  class ChildWorkflowSignalCommandsWorkflow < Temporalio::Workflow::Definition
    def execute
      direct = Temporalio::Workflow.create_event_group('direct')
      scope = Temporalio::Workflow.create_event_group('scope')
      child = Temporalio::Workflow.start_child_workflow(
        WaitForSignalChildWorkflow,
        id: "#{Temporalio::Workflow.info.workflow_id}_child"
      )
      Temporalio::Workflow.with_event_groups(scope) { child.signal(:noop, event_groups: [direct]) }
      child.result
    end
  end

  def test_child_workflow_signal_commands_carry_markers
    run_and_events(
      ChildWorkflowSignalCommandsWorkflow,
      activities: [],
      more_workflows: [WaitForSignalChildWorkflow]
    ) do |_handle, events|
      both = [label_marker_id('direct'), label_marker_id('scope')]
      assert_markers(single_event(events, :EVENT_TYPE_SIGNAL_EXTERNAL_WORKFLOW_EXECUTION_INITIATED), *both)
    end
  end

  class MetadataCommandsWorkflow < Temporalio::Workflow::Definition
    def execute
      direct = Temporalio::Workflow.create_event_group('direct')
      scope = Temporalio::Workflow.create_event_group('scope')
      Temporalio::Workflow.with_event_groups(scope) do
        Temporalio::Workflow.upsert_memo({ 'some-key' => 'some-value' }, event_groups: [direct])
        Temporalio::Workflow.upsert_search_attributes(
          WorkerWorkflowEventGroupsTest::ATTR_KEY_BOOLEAN.value_set(false),
          event_groups: [direct]
        )
        Temporalio::Workflow.patched('my-patch-1', event_groups: [direct])
        Temporalio::Workflow.deprecate_patch('my-patch-2', event_groups: [direct])
      end
    end
  end

  def test_metadata_commands_carry_markers
    env.ensure_common_search_attribute_keys
    run_and_events(MetadataCommandsWorkflow, activities: []) do |_handle, events|
      both = [label_marker_id('direct'), label_marker_id('scope')]
      assert_markers(single_event(events, :EVENT_TYPE_WORKFLOW_PROPERTIES_MODIFIED), *both)
      patches = markers_named(events, 'core_patch')
      assert_equal 2, patches.size
      patches.each { |patch| assert_markers(patch, *both) }
      upserts = events_of_type(events, :EVENT_TYPE_UPSERT_WORKFLOW_SEARCH_ATTRIBUTES)
      assert_equal 3, upserts.size
      upserts.each { |upsert| assert_markers(upsert, *both) }
    end
  end

  class ContinueAsNewCommandsWorkflow < Temporalio::Workflow::Definition
    def execute(second_run = nil)
      return if second_run

      direct = Temporalio::Workflow.create_event_group('direct')
      scope = Temporalio::Workflow.create_event_group('scope')
      Temporalio::Workflow.with_event_groups(scope) do
        raise Temporalio::Workflow::ContinueAsNewError.new(true, event_groups: [direct])
      end
    end
  end

  def test_continue_as_new_carries_markers
    execute_workflow(ContinueAsNewCommandsWorkflow, false, activities: []) do |handle|
      handle.result
      first = env.client.workflow_handle(handle.id, run_id: handle.first_execution_run_id)
      events = fetch_events(first)
      both = [label_marker_id('direct'), label_marker_id('scope')]
      assert_markers(single_event(events, :EVENT_TYPE_WORKFLOW_EXECUTION_CONTINUED_AS_NEW), *both)
    end
  end

  class EmptyIdAndLabelWorkflow < Temporalio::Workflow::Definition
    def execute
      errors = []
      begin
        Temporalio::Workflow.create_event_group('')
      rescue ArgumentError => e
        errors << e.message
      end
      begin
        Temporalio::Workflow.create_event_group('id', label: '')
      rescue ArgumentError => e
        errors << e.message
      end
      errors
    end
  end

  def test_event_group_rejects_empty_id_and_label
    assert_equal(
      ['Event group id cannot be empty', 'Event group label cannot be empty'],
      execute_workflow(EmptyIdAndLabelWorkflow, activities: [])
    )
  end

  def test_create_event_group_requires_workflow_context
    err = assert_raises(Temporalio::Error) { Temporalio::Workflow.create_event_group('outside-workflow') }
    assert_equal 'Not in workflow environment', err.message
  end
end
