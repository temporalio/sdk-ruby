# frozen_string_literal: true

require 'async'
require 'temporalio/client'
require 'temporalio/client/schedule'
require 'temporalio/testing'
require 'test'

class ClientScheduleTest < Test
  also_run_all_tests_in_fiber

  def test_basics # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    assert_no_schedules

    # Create a schedule with lots of things
    task_queue = "tq-#{SecureRandom.uuid}"
    action = Temporalio::Client::Schedule::Action::StartWorkflow.new(
      'kitchen_sink',
      { actions: [{ result: { value: 'some-result' } }] },
      id: "wf-#{SecureRandom.uuid}",
      task_queue:,
      execution_timeout: 1.23,
      memo: { 'memokey1' => 'memoval1' }
    )
    schedule = Temporalio::Client::Schedule.new(
      action:,
      spec: Temporalio::Client::Schedule::Spec.new(
        calendars: [
          Temporalio::Client::Schedule::Spec::Calendar.new(
            second: [Temporalio::Client::Schedule::Range.new(1)],
            minute: [Temporalio::Client::Schedule::Range.new(2, 3)],
            hour: [Temporalio::Client::Schedule::Range.new(4, 5, 6)],
            day_of_month: [Temporalio::Client::Schedule::Range.new(7)],
            month: [Temporalio::Client::Schedule::Range.new(9)],
            year: [Temporalio::Client::Schedule::Range.new(2080)],
            # Intentionally leave day of week absent to check default
            comment: 'spec comment 1'
          )
        ],
        intervals: [
          Temporalio::Client::Schedule::Spec::Interval.new(
            every: 10 * 24 * 60 * 60.0, # 10d
            offset: 2 * 24 * 60 * 60.0 # 2d
          )
        ],
        cron_expressions: ['0 12 * * MON'],
        skip: [Temporalio::Client::Schedule::Spec::Calendar.new(year: [Temporalio::Client::Schedule::Range.new(2080)])],
        start_at: Time.utc(2060, 7, 8, 9, 10, 11),
        jitter: 8.9
      ),
      policy: Temporalio::Client::Schedule::Policy.new(
        overlap: Temporalio::Client::Schedule::OverlapPolicy::BUFFER_ONE,
        catchup_window: 5 * 60.0,
        pause_on_failure: true
      ),
      state: Temporalio::Client::Schedule::State.new(
        note: 'sched note 1',
        paused: true,
        limited_actions: true,
        remaining_actions: 30
      )
    )
    handle = env.client.create_schedule(
      "sched-#{SecureRandom.uuid}",
      schedule,
      memo: { 'memokey2' => 'memoval2' }
    )

    # Describe it and check values
    desc = handle.describe
    assert_equal handle.id, desc.id
    desc_action = desc.schedule.action #: Temporalio::Client::Schedule::Action::StartWorkflow
    assert_instance_of Temporalio::Client::Schedule::Action::StartWorkflow, desc_action
    assert_equal action.workflow, desc_action.workflow
    assert_equal 'some-result', desc_action.args.first['actions'].first['result']['value'] # steep:ignore
    assert_equal action.execution_timeout, desc_action.execution_timeout
    assert_equal({ 'memokey1' => 'memoval1' }, desc_action.memo)
    assert_equal({ 'memokey2' => 'memoval2' }, desc.memo)
    # We want to test the entire returned spec, policy, and state. But server
    # side spec turns the cron into a calendar, so we will replicate in our
    # expected spec.
    expected_spec = schedule.spec.dup
    expected_spec.cron_expressions = []
    expected_spec.calendars.push(
      Temporalio::Client::Schedule::Spec::Calendar.new(
        second: [Temporalio::Client::Schedule::Range.new(0)],
        minute: [Temporalio::Client::Schedule::Range.new(0)],
        hour: [Temporalio::Client::Schedule::Range.new(12)],
        day_of_month: [Temporalio::Client::Schedule::Range.new(1, 31)],
        month: [Temporalio::Client::Schedule::Range.new(1, 12)],
        day_of_week: [Temporalio::Client::Schedule::Range.new(1)]
      )
    )
    assert_equal expected_spec, desc.schedule.spec
    assert_equal schedule.policy, desc.schedule.policy
    assert_equal schedule.state, desc.schedule.state

    # Update to just change schedule workflow's task timeout
    assert_nil desc_action.task_timeout
    handle.update do |input|
      to_update = input.description.schedule.dup
      assert_instance_of Temporalio::Client::Schedule::Action::StartWorkflow, to_update.action
      to_update.action.task_timeout = 4.56 # steep:ignore
      Temporalio::Client::Schedule::Update.new(schedule: to_update)
    end
    desc = handle.describe
    desc_action = desc.schedule.action #: Temporalio::Client::Schedule::Action::StartWorkflow
    assert_equal 4.56, desc_action.task_timeout

    # Update but return nil to discard/cancel update
    expected_updated_at = desc.info.last_updated_at
    handle.update { nil }
    assert_equal expected_updated_at, handle.describe.info.last_updated_at

    # Update to schedule of simple defaults
    new_schedule = Temporalio::Client::Schedule.new(
      action:,
      spec: Temporalio::Client::Schedule::Spec.new,
      state: Temporalio::Client::Schedule::State.new(paused: true)
    )
    handle.update { Temporalio::Client::Schedule::Update.new(schedule: new_schedule) }
    desc = handle.describe
    refute_equal expected_updated_at, desc.info.last_updated_at

    # Attempt to create duplicate
    assert_raises(Temporalio::Error::ScheduleAlreadyRunningError) do
      env.client.create_schedule(handle.id, new_schedule)
    end

    # Confirm paused
    assert desc.schedule.state.paused
    # Pause and confirm still paused
    handle.pause
    desc = handle.describe
    assert desc.schedule.state.paused
    assert_equal 'Paused via Ruby SDK', desc.schedule.state.note
    # Unpause
    handle.unpause
    desc = handle.describe
    refute desc.schedule.state.paused
    assert_equal 'Unpaused via Ruby SDK', desc.schedule.state.note
    # Pause with custom message
    handle.pause(note: 'test1')
    desc = handle.describe
    assert desc.schedule.state.paused
    assert_equal 'test1', desc.schedule.state.note
    # Unpause with custom message
    handle.unpause(note: 'test2')
    desc = handle.describe
    refute desc.schedule.state.paused
    assert_equal 'test2', desc.schedule.state.note

    # Trigger with worker running
    env.with_kitchen_sink_worker(task_queue:) do
      assert_equal 0, desc.info.num_actions
      handle.trigger
      assert_eventually do
        desc = handle.describe
        assert_equal 1, desc.info.num_actions
      end

      # Check results
      exec = desc.info.recent_actions.first&.action #: Temporalio::Client::Schedule::ActionExecution::StartWorkflow
      assert_instance_of Temporalio::Client::Schedule::ActionExecution::StartWorkflow, exec
      assert_equal 'some-result',
                   env.client.workflow_handle(exec.workflow_id,
                                              first_execution_run_id: exec.first_execution_run_id).result
    end

    # Create 4 more schedules of the same type and confirm they are in the list
    # eventually. But create two with different search attributes.
    env.ensure_common_search_attribute_keys
    expected_ids = [handle.id] + 4.times.map do |index|
      env.client.create_schedule(
        "#{handle.id}-#{index + 1}",
        new_schedule,
        search_attributes: if index >= 2
                             Temporalio::SearchAttributes.new(
                               { ATTR_KEY_KEYWORD => 'sched-test', ATTR_KEY_INTEGER => 1234 }
                             )
                           end
      ).id
    end
    assert_eventually do
      assert_equal expected_ids, env.client.list_schedules.map(&:id).sort
    end

    # Confirm list with query works
    assert_equal ["#{handle.id}-3", "#{handle.id}-4"],
                 env.client.list_schedules("`#{ATTR_KEY_KEYWORD.name}` = 'sched-test'").map(&:id).sort

    # Update the SAs of the 3rd schedule, wipe out the SAs of the 4th, confirm
    # they are no longer in the list with 'sched-test'
    handle3 = env.client.schedule_handle("#{handle.id}-3")
    handle4 = env.client.schedule_handle("#{handle.id}-4")
    handle3.update do |input|
      new_attrs = Temporalio::SearchAttributes.new(input.description.search_attributes || raise)
      new_attrs[ATTR_KEY_KEYWORD] = 'sched-test2'
      Temporalio::Client::Schedule::Update.new(
        schedule: input.description.schedule,
        search_attributes: new_attrs
      )
    end
    handle4.update do |input|
      Temporalio::Client::Schedule::Update.new(
        schedule: input.description.schedule,
        search_attributes: Temporalio::SearchAttributes.new
      )
    end
    assert_eventually do
      assert env.client.list_schedules("`#{ATTR_KEY_KEYWORD.name}` = 'sched-test'").to_a.empty?
    end
    # Verify that 3 is still present and 4 is not with the integer attribute
    assert_eventually do
      assert_equal [handle3.id], env.client.list_schedules("`#{ATTR_KEY_INTEGER.name}` = 1234").map(&:id)
    end
  ensure
    delete_all_schedules
  end

  def test_calendar_spec_defaults
    assert_no_schedules

    handle = env.client.create_schedule(
      "sched-#{SecureRandom.uuid}",
      Temporalio::Client::Schedule.new(
        action: Temporalio::Client::Schedule::Action::StartWorkflow.new(
          'kitchen_sink',
          { actions: [{ result: { value: 'some-result' } }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue: "tq-#{SecureRandom.uuid}"
        ),
        spec: Temporalio::Client::Schedule::Spec.new(
          calendars: [Temporalio::Client::Schedule::Spec::Calendar.new]
        ),
        state: Temporalio::Client::Schedule::State.new(paused: true)
      )
    )
    desc = handle.describe
    assert_equal Temporalio::Client::Schedule::Spec::Calendar.new, desc.schedule.spec.calendars.first

    # Make sure that every next time has all zero time portion and is one day
    # after the previous
    assert_equal 10, desc.info.next_action_times.size
    desc.info.next_action_times.each_with_index do |next_action_time, i|
      assert next_action_time.utc?
      assert next_action_time.sec.zero?
      assert next_action_time.min.zero?
      assert next_action_time.hour.zero?
      assert_equal desc.info.next_action_times[i - 1] + (24 * 60 * 60), next_action_time unless i.zero?
    end
  ensure
    delete_all_schedules
  end

  def test_trigger_immediately
    assert_no_schedules

    env.with_kitchen_sink_worker do |task_queue|
      handle = env.client.create_schedule(
        "sched-#{SecureRandom.uuid}",
        Temporalio::Client::Schedule.new(
          action: Temporalio::Client::Schedule::Action::StartWorkflow.new(
            'kitchen_sink',
            { actions: [{ result: { value: 'some-result' } }] },
            id: "wf-#{SecureRandom.uuid}",
            task_queue:
          ),
          spec: Temporalio::Client::Schedule::Spec.new,
          state: Temporalio::Client::Schedule::State.new(paused: true)
        ),
        trigger_immediately: true
      )

      # Confirm result
      desc = handle.describe
      assert_equal 1, desc.info.num_actions
      exec = desc.info.recent_actions.first&.action #: Temporalio::Client::Schedule::ActionExecution::StartWorkflow
      assert_instance_of Temporalio::Client::Schedule::ActionExecution::StartWorkflow, exec
      assert_equal 'some-result', env.client.workflow_handle(exec.workflow_id).result
    end
  ensure
    delete_all_schedules
  end

  def test_backfill
    assert_no_schedules

    # Create paused schedule that runs every minute and has two backfills
    now = Time.now(in: 'UTC')
    # Intervals align to the epoch boundary, so trim off sub-minute
    now = Time.new(now.year, now.month, now.day, now.hour, now.min, 0, now.utc_offset)

    handle = env.client.create_schedule(
      "sched-#{SecureRandom.uuid}",
      Temporalio::Client::Schedule.new(
        action: Temporalio::Client::Schedule::Action::StartWorkflow.new(
          'kitchen_sink',
          { actions: [{ result: { value: 'some-result' } }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue: "tq-#{SecureRandom.uuid}"
        ),
        spec: Temporalio::Client::Schedule::Spec.new(
          intervals: [Temporalio::Client::Schedule::Spec::Interval.new(every: 60.0)]
        ),
        state: Temporalio::Client::Schedule::State.new(paused: true)
      ),
      # Backfill from -10m1s to -9m and confirm 2 count
      backfills: [Temporalio::Client::Schedule::Backfill.new(
        start_at: now - ((10 * 60) + 1),
        end_at: now - (9 * 60),
        overlap: Temporalio::Client::Schedule::OverlapPolicy::ALLOW_ALL
      )]
    )
    assert_equal 2, handle.describe.info.num_actions

    # Add two more backfills and -2m will be deduped
    handle.backfill(
      Temporalio::Client::Schedule::Backfill.new(
        start_at: now - (4 * 60),
        end_at: now - (2 * 60),
        overlap: Temporalio::Client::Schedule::OverlapPolicy::ALLOW_ALL
      ),
      Temporalio::Client::Schedule::Backfill.new(
        start_at: now - (2 * 60),
        end_at: now,
        overlap: Temporalio::Client::Schedule::OverlapPolicy::ALLOW_ALL
      )
    )
    # Servers < 1.24 this is 6, servers >= 1.24 this is 7, but we assume our
    # tests are always on 1.24+
    assert_equal 7, handle.describe.info.num_actions
  ensure
    delete_all_schedules
  end
end
