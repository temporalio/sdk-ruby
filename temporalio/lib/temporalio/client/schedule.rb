# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/converters'
require 'temporalio/internal/proto_utils'
require 'temporalio/retry_policy'
require 'temporalio/search_attributes'

module Temporalio
  class Client
    Schedule = Data.define(
      :action,
      :spec,
      :policy,
      :state
    )

    # A schedule for periodically running an action.
    #
    # @!attribute action
    #   @return [Action] Action taken when scheduled.
    # @!attribute spec
    #   @return [Spec] When the action is taken.
    # @!attribute policy
    #   @return [Policy] Schedule policies.
    # @!attribute state
    #   @return [State] State of the schedule.
    class Schedule
      # @!visibility private
      def self._from_proto(raw_schedule, data_converter)
        Schedule.new(
          action: Action._from_proto(raw_schedule.action, data_converter),
          spec: Spec._from_proto(raw_schedule.spec),
          policy: Policy._from_proto(raw_schedule.policies),
          state: State._from_proto(raw_schedule.state)
        )
      end

      # Create schedule
      #
      # @param action [Action] Action taken when scheduled.
      # @param spec [Spec] When the action is taken.
      # @param policy [Policy] Schedule policies.
      # @param state [State] State of the schedule.
      def initialize(action:, spec:, policy: Policy.new, state: State.new)
        super
      end

      # @!visibility private
      def _to_proto(data_converter)
        Api::Schedule::V1::Schedule.new(
          spec: spec._to_proto,
          action: action._to_proto(data_converter),
          policies: policy._to_proto,
          state: state._to_proto
        )
      end

      Description = Data.define( # rubocop:disable Layout/ClassStructure
        :id,
        :schedule,
        :info,
        :raw_description
      )

      # Description of a schedule.
      #
      # @!attribute id
      #   @return [String] ID of the schedule.
      # @!attribute schedule
      #   @return [Schedule] Schedule details.
      # @!attribute info
      #   @return [Schedule::Info] Information about the schedule.
      # @!attribute raw_description
      #   @return [Api::WorkflowService::V1::DescribeScheduleResponse] Raw description of the schedule.
      class Description
        # @!visibility private
        def initialize(id:, raw_description:, data_converter:)
          @memo = Internal::ProtoUtils::LazyMemo.new(raw_description.memo, data_converter)
          @search_attributes = Internal::ProtoUtils::LazySearchAttributes.new(raw_description.search_attributes)
          # steep:ignore:start
          super(
            id:,
            schedule: Schedule._from_proto(raw_description.schedule, data_converter),
            info: Info.new(raw_info: raw_description.info),
            raw_description:
          )
          # steep:ignore:end
        end

        # @return [Hash<String, Object>, nil] Memo for the schedule, converted lazily on first call.
        def memo
          @memo.get
        end

        # @return [SearchAttributes, nil] Search attributes for the schedule, converted lazily on first call.
        def search_attributes
          @search_attributes.get
        end
      end

      Info = Data.define(
        :num_actions,
        :num_actions_missed_catchup_window,
        :num_actions_skipped_overlap,
        :running_actions,
        :recent_actions,
        :next_action_times,
        :created_at,
        :last_updated_at
      )

      # Information about a schedule.
      #
      # @!attribute num_actions
      #   @return [Integer] Number of actions taken by this schedule.
      # @!attribute num_actions_missed_catchup_window
      #   @return [Integer] Number of times an action was skipped due to missing the catchup window.
      # @!attribute num_actions_skipped_overlap
      #   @return [Integer] Number of actions skipped due to overlap.
      # @!attribute running_actions
      #   @return [Array<ActionExecution>] Currently running actions.
      # @!attribute recent_actions
      #   @return [Array<ActionResult>] 10 most recent actions, oldest first.
      # @!attribute next_action_times
      #   @return [Array<Time>] Next 10 scheduled action times.
      # @!attribute created_at
      #   @return [Time] When the schedule was created.
      # @!attribute last_updated_at
      #   @return [Time, nil] When the schedule was last updated.
      class Info
        # @!visibility private
        def initialize(raw_info:)
          # steep:ignore:start
          super(
            num_actions: raw_info.action_count,
            num_actions_missed_catchup_window: raw_info.missed_catchup_window,
            num_actions_skipped_overlap: raw_info.overlap_skipped,
            running_actions: raw_info.running_workflows.map do |w|
              ActionExecution::StartWorkflow.new(raw_execution: w)
            end,
            recent_actions: raw_info.recent_actions.map { |a| ActionResult.new(raw_result: a) },
            next_action_times: raw_info.future_action_times.map { |t| Internal::ProtoUtils.timestamp_to_time(t) },
            created_at: Internal::ProtoUtils.timestamp_to_time(raw_info.create_time),
            last_updated_at: Internal::ProtoUtils.timestamp_to_time(raw_info.update_time)
          )
          # steep:ignore:end
        end
      end

      # Base module mixed in by specific actions a schedule can take.
      module Action
        # @!visibility private
        def self._from_proto(raw_action, data_converter)
          raise "Unsupported action: #{raw_action.action}" unless raw_action.start_workflow

          StartWorkflow._from_proto(raw_action.start_workflow, data_converter)
        end

        # @!visibility private
        def _to_proto(data_converter)
          raise NotImplementedError
        end

        StartWorkflow = Data.define(
          :workflow,
          :args,
          :id,
          :task_queue,
          :execution_timeout,
          :run_timeout,
          :task_timeout,
          :retry_policy,
          :memo,
          :search_attributes,
          :headers
        )

        # Schedule action to start a workflow.
        #
        # @!attribute workflow
        #   @return [String] Workflow.
        # @!attribute args
        #   @return [Array<Object>] Arguments to the workflow.
        # @!attribute id
        #   @return [String] Unique identifier for the workflow execution.
        # @!attribute task_queue
        #   @return [String] Task queue to run the workflow on.
        # @!attribute execution_timeout
        #   @return [Float, nil] Total workflow execution timeout in seconds including retries and continue as new.
        # @!attribute run_timeout
        #   @return [Float, nil] Timeout of a single workflow run in seconds.
        # @!attribute task_timeout
        #   @return [Float, nil] Timeout of a single workflow task in seconds.
        # @!attribute retry_policy
        #   @return [RetryPolicy, nil] Retry policy for the workflow.
        # @!attribute memo
        #   @return [Hash<String, Object>, nil] Memo for the workflow.
        # @!attribute search_attributes
        #   @return [SearchAttributes, nil] Search attributes for the workflow.
        # @!attribute headers
        #   @return [Hash<String, Object>, nil] Headers for the workflow.
        class StartWorkflow
          include Action

          class << self
            alias _original_new new

            # Create start-workflow schedule action.
            #
            # @param workflow [Class<Workflow::Definition>, Symbol, String] Workflow.
            # @param args [Array<Object>] Arguments to the workflow.
            # @param id [String] Unique identifier for the workflow execution.
            # @param task_queue [String] Task queue to run the workflow on.
            # @param execution_timeout [Float, nil] Total workflow execution timeout in seconds including retries and
            #   continue as new.
            # @param run_timeout [Float, nil] Timeout of a single workflow run in seconds.
            # @param task_timeout [Float, nil] Timeout of a single workflow task in seconds.
            # @param retry_policy [RetryPolicy, nil] Retry policy for the workflow.
            # @param memo [Hash<String, Object>, nil] Memo for the workflow.
            # @param search_attributes [SearchAttributes, nil] Search attributes for the workflow.
            # @param headers [Hash<String, Object>, nil] Headers for the workflow.
            def new(
              workflow,
              *args,
              id:,
              task_queue:,
              execution_timeout: nil,
              run_timeout: nil,
              task_timeout: nil,
              retry_policy: nil,
              memo: nil,
              search_attributes: nil,
              headers: nil
            )
              _original_new( # steep:ignore
                workflow: Workflow::Definition._workflow_type_from_workflow_parameter(workflow),
                args:,
                id:,
                task_queue:,
                execution_timeout:,
                run_timeout:,
                task_timeout:,
                retry_policy:,
                memo:,
                search_attributes:,
                headers:
              )
            end
          end

          # @!visibility private
          def self._from_proto(raw_info, data_converter)
            StartWorkflow.new(
              raw_info.workflow_type.name,
              *data_converter.from_payloads(raw_info.input),
              id: raw_info.workflow_id,
              task_queue: raw_info.task_queue.name,
              execution_timeout: Internal::ProtoUtils.duration_to_seconds(raw_info.workflow_execution_timeout),
              run_timeout: Internal::ProtoUtils.duration_to_seconds(raw_info.workflow_run_timeout),
              task_timeout: Internal::ProtoUtils.duration_to_seconds(raw_info.workflow_task_timeout),
              retry_policy: raw_info.retry_policy ? RetryPolicy._from_proto(raw_info.retry_policy) : nil,
              memo: Internal::ProtoUtils.memo_from_proto(raw_info.memo, data_converter),
              search_attributes: SearchAttributes._from_proto(raw_info.search_attributes),
              headers: Internal::ProtoUtils.headers_from_proto(raw_info.header, data_converter)
            )
          end

          # @!visibility private
          def _to_proto(data_converter)
            Api::Schedule::V1::ScheduleAction.new(
              start_workflow: Api::Workflow::V1::NewWorkflowExecutionInfo.new(
                workflow_id: id,
                workflow_type: Api::Common::V1::WorkflowType.new(name: workflow),
                task_queue: Api::TaskQueue::V1::TaskQueue.new(name: task_queue),
                input: data_converter.to_payloads(args),
                workflow_execution_timeout: Internal::ProtoUtils.seconds_to_duration(execution_timeout),
                workflow_run_timeout: Internal::ProtoUtils.seconds_to_duration(run_timeout),
                workflow_task_timeout: Internal::ProtoUtils.seconds_to_duration(task_timeout),
                retry_policy: retry_policy&._to_proto,
                memo: Internal::ProtoUtils.memo_to_proto(memo, data_converter),
                search_attributes: search_attributes&._to_proto,
                header: Internal::ProtoUtils.headers_to_proto(headers, data_converter)
              )
            )
          end
        end
      end

      # Enumerate that controls what happens when a workflow would be started by a schedule but one is already running.
      module OverlapPolicy
        # Don't start anything. When the workflow completes, the next scheduled event after that time will be
        # considered.
        SKIP = Api::Enums::V1::ScheduleOverlapPolicy::SCHEDULE_OVERLAP_POLICY_SKIP

        # Start the workflow again soon as the current one completes, but only buffer one start in this way. If another
        # start is supposed to happen when the workflow is running, and one is already buffered, then only the first one
        # will be started after the running workflow finishes.
        BUFFER_ONE = Api::Enums::V1::ScheduleOverlapPolicy::SCHEDULE_OVERLAP_POLICY_BUFFER_ONE

        # Buffer up any number of starts to all happen sequentially, immediately after the running workflow completes.
        BUFFER_ALL = Api::Enums::V1::ScheduleOverlapPolicy::SCHEDULE_OVERLAP_POLICY_BUFFER_ALL

        # If there is another workflow running, cancel it, and start the new one after the old one completes
        # cancellation.
        CANCEL_OTHER = Api::Enums::V1::ScheduleOverlapPolicy::SCHEDULE_OVERLAP_POLICY_CANCEL_OTHER

        # If there is another workflow running, terminate it and start the new one immediately.
        TERMINATE_OTHER = Api::Enums::V1::ScheduleOverlapPolicy::SCHEDULE_OVERLAP_POLICY_TERMINATE_OTHER

        # Start any number of concurrent workflows. Note that with this policy, last completion result and last failure
        # will not be available since workflows are not sequential.
        ALLOW_ALL = Api::Enums::V1::ScheduleOverlapPolicy::SCHEDULE_OVERLAP_POLICY_ALLOW_ALL
      end

      Backfill = Data.define(
        :start_at,
        :end_at,
        :overlap
      )

      # Time period and policy for actions taken as if the time passed right now.
      #
      # @!attribute start_at
      #   @return [Time] Start of the range to evaluate the schedule in. This is exclusive.
      # @!attribute end_at
      #   @return [Time] End of the range to evaluate the schedule in. This is inclusive.
      # @!attribute overlap
      #   @return [OverlapPolicy] Overlap policy.
      class Backfill
        # Create backfill.
        #
        # @param start_at [Time] Start of the range to evaluate the schedule in. This is exclusive.
        # @param end_at [Time] End of the range to evaluate the schedule in. This is inclusive.
        # @param overlap [OverlapPolicy] Overlap policy.
        def initialize(
          start_at:,
          end_at:,
          overlap: nil
        )
          super
        end

        # @!visibility private
        def _to_proto
          Api::Schedule::V1::BackfillRequest.new(
            start_time: Internal::ProtoUtils.time_to_timestamp(start_at),
            end_time: Internal::ProtoUtils.time_to_timestamp(end_at),
            overlap_policy: overlap || Api::Enums::V1::ScheduleOverlapPolicy::SCHEDULE_OVERLAP_POLICY_UNSPECIFIED
          )
        end
      end

      # Base module mixed in by specific action executions.
      module ActionExecution
        StartWorkflow = Data.define(
          :workflow_id,
          :first_execution_run_id
        )

        # Execution of a scheduled workflow start.
        #
        # @!attribute workflow_id
        #   @return [String] Workflow ID.
        # @!attribute first_execution_run_id
        #   @return [String] Workflow run ID.
        class StartWorkflow
          include ActionExecution

          # @!visibility private
          def initialize(raw_execution:)
            # steep:ignore:start
            super(
              workflow_id: raw_execution.workflow_id,
              first_execution_run_id: raw_execution.run_id
            )
            # steep:ignore:end
          end
        end
      end

      ActionResult = Data.define(
        :scheduled_at,
        :started_at,
        :action
      )

      # Information about when an action took place.
      #
      # @!attribute scheduled_at
      #   @return [Time] Scheduled time of the action including jitter.
      # @!attribute started_at
      #   @return [Time] When the action actually started.
      # @!attribute action
      #   @return [ActionExecution] Action that took place.
      class ActionResult
        # @!visibility private
        def initialize(raw_result:)
          # steep:ignore:start
          super(
            scheduled_at: Internal::ProtoUtils.timestamp_to_time(raw_result.schedule_time),
            started_at: Internal::ProtoUtils.timestamp_to_time(raw_result.actual_time),
            action: ActionExecution::StartWorkflow.new(raw_execution: raw_result.start_workflow_result)
          )
          # steep:ignore:end
        end
      end

      Spec = Data.define(
        :calendars,
        :intervals,
        :cron_expressions,
        :skip,
        :start_at,
        :end_at,
        :jitter,
        :time_zone_name
      )

      # Specification of the times scheduled actions may occur.
      #
      # The times are the union of {calendars}, {intervals}, and {cron_expressions} excluding anything in {skip}.
      #
      # @!attribute calendars
      #   @return [Array<Calendar>] Calendar-based specification of times.
      # @!attribute intervals
      #   @return [Array<Interval>] Interval-based specification of times.
      # @!attribute cron_expressions
      #   @return [Array<String>] Cron-based specification of times. This is provided for easy migration
      #     from legacy string-based cron scheduling. New uses should use `calendars` instead. These expressions will be
      #     translated to calendar-based specifications on the server.
      # @!attribute skip
      #   @return [Array<Calendar>] Set of matching calendar times that will be skipped.
      # @!attribute start_at
      #   @return [Time, nil] Time before which any matching times will be skipped.
      # @!attribute end_at
      #   @return [Time, nil] Time after which any matching times will be skipped.
      # @!attribute jitter
      #   @return [Float, nil] Jitter to apply each action. An action's scheduled time will be incremented by a random
      #     value between 0 and this value if present (but not past the next schedule).
      # @!attribute time_zone_name
      #   @return [String, nil] IANA time zone name, for example `US/Central`.
      class Spec
        # @!visibility private
        def self._from_proto(raw_spec)
          Schedule::Spec.new(
            calendars: raw_spec.structured_calendar.map { |c| Calendar._from_proto(c) },
            intervals: raw_spec.interval.map { |c| Interval._from_proto(c) },
            cron_expressions: raw_spec.cron_string.to_a,
            skip: raw_spec.exclude_structured_calendar.map { |c| Calendar._from_proto(c) },
            start_at: Internal::ProtoUtils.timestamp_to_time(raw_spec.start_time),
            end_at: Internal::ProtoUtils.timestamp_to_time(raw_spec.end_time),
            jitter: Internal::ProtoUtils.duration_to_seconds(raw_spec.jitter),
            time_zone_name: Internal::ProtoUtils.string_or(raw_spec.timezone_name)
          )
        end

        # Create a spec.
        #
        # @param calendars [Array<Calendar>] Calendar-based specification of times.
        # @param intervals [Array<Interval>] Interval-based specification of times.
        # @param cron_expressions [Array<String>] Cron-based specification of times. This is provided for easy migration
        #   from legacy string-based cron scheduling. New uses should use `calendars` instead. These expressions will be
        #   translated to calendar-based specifications on the server.
        # @param skip [Array<Calendar>] Set of matching calendar times that will be skipped.
        # @param start_at [Time, nil] Time before which any matching times will be skipped.
        # @param end_at [Time, nil] Time after which any matching times will be skipped.
        # @param jitter [Float, nil] Jitter to apply each action. An action's scheduled time will be incremented by a
        #   random value between 0 and this value if present (but not past the next schedule).
        # @param time_zone_name [String, nil] IANA time zone name, for example `US/Central`.
        def initialize(
          calendars: [],
          intervals: [],
          cron_expressions: [],
          skip: [],
          start_at: nil,
          end_at: nil,
          jitter: nil,
          time_zone_name: nil
        )
          super
        end

        # @!visibility private
        def _to_proto
          Api::Schedule::V1::ScheduleSpec.new(
            structured_calendar: calendars.map(&:_to_proto),
            cron_string: cron_expressions,
            interval: intervals.map(&:_to_proto),
            exclude_structured_calendar: skip.map(&:_to_proto),
            start_time: Internal::ProtoUtils.time_to_timestamp(start_at),
            end_time: Internal::ProtoUtils.time_to_timestamp(end_at),
            jitter: Internal::ProtoUtils.seconds_to_duration(jitter),
            timezone_name: time_zone_name || ''
          )
        end

        Calendar = Data.define( # rubocop:disable Layout/ClassStructure
          :second,
          :minute,
          :hour,
          :day_of_month,
          :month,
          :year,
          :day_of_week,
          :comment
        )

        # Specification relative to calendar time when to run an action.
        #
        # A timestamp matches if at least one range of each field matches except for year. If year is missing, that
        # means all years match. For all fields besides year, at least one range must be present to match anything.
        #
        # @!attribute second
        #   @return [Array<Range>] Second range to match, 0-59. Default matches 0.
        # @!attribute minute
        #   @return [Array<Range>] Minute range to match, 0-59. Default matches 0.
        # @!attribute hour
        #   @return [Array<Range>] Hour range to match, 0-23. Default matches 0.
        # @!attribute day_of_month
        #   @return [Array<Range>] Day of month range to match, 1-31. Default matches all days.
        # @!attribute month
        #   @return [Array<Range>] Month range to match, 1-12. Default matches all months.
        # @!attribute year
        #   @return [Array<Range>] Optional year range to match. Default of empty matches all years.
        # @!attribute day_of_week
        #   @return [Array<Range>] Day of week range to match, 0-6, 0 is Sunday. Default matches all days.
        # @!attribute comment
        #   @return [String, nil] Description of this schedule.
        class Calendar
          # @!visibility private
          def self._from_proto(raw_cal)
            Calendar.new(
              second: Range._from_protos(raw_cal.second),
              minute: Range._from_protos(raw_cal.minute),
              hour: Range._from_protos(raw_cal.hour),
              day_of_month: Range._from_protos(raw_cal.day_of_month),
              month: Range._from_protos(raw_cal.month),
              year: Range._from_protos(raw_cal.year),
              day_of_week: Range._from_protos(raw_cal.day_of_week),
              comment: Internal::ProtoUtils.string_or(raw_cal.comment)
            )
          end

          # Create a calendar spec.
          #
          # @param second [Array<Range>] Second range to match, 0-59. Default matches 0.
          # @param minute [Array<Range>] Minute range to match, 0-59. Default matches 0.
          # @param hour [Array<Range>] Hour range to match, 0-23. Default matches 0.
          # @param day_of_month [Array<Range>] Day of month range to match, 1-31. Default matches all days.
          # @param month [Array<Range>] Month range to match, 1-12. Default matches all months.
          # @param year [Array<Range>] Optional year range to match. Default of empty matches all years.
          # @param day_of_week [Array<Range>] Day of week range to match, 0-6, 0 is Sunday. Default matches all days.
          # @param comment [String, nil] Description of this schedule.
          def initialize(
            second: [Range.new(0)],
            minute: [Range.new(0)],
            hour: [Range.new(0)],
            day_of_month: [Range.new(1, 31)],
            month: [Range.new(1, 12)],
            year: [],
            day_of_week: [Range.new(0, 6)],
            comment: nil
          )
            super
          end

          # @!visibility private
          def _to_proto
            Api::Schedule::V1::StructuredCalendarSpec.new(
              second: Range._to_protos(second),
              minute: Range._to_protos(minute),
              hour: Range._to_protos(hour),
              day_of_month: Range._to_protos(day_of_month),
              month: Range._to_protos(month),
              year: Range._to_protos(year),
              day_of_week: Range._to_protos(day_of_week),
              comment: comment || ''
            )
          end
        end

        Interval = Data.define(
          :every,
          :offset
        )

        # Specification for scheduling on an interval.
        #
        # Matches times expressed as epoch + (n * every) + offset.
        #
        # @!attribute every
        #   @return [Float] Period to repeat the interval.
        # @!attribute offset
        #   @return [Float, nil] Fixed offset added to each interval period.
        class Interval
          # @!visibility private
          def self._from_proto(raw_int)
            Schedule::Spec::Interval.new(
              every: Internal::ProtoUtils.duration_to_seconds(raw_int.interval) || raise, # Never nil
              offset: Internal::ProtoUtils.duration_to_seconds(raw_int.phase)
            )
          end

          # Create an interval spec.
          #
          # @param every [Float] Period to repeat the interval.
          # @param offset [Float, nil] Fixed offset added to each interval period.
          def initialize(every:, offset: nil)
            super
          end

          # @!visibility private
          def _to_proto
            Api::Schedule::V1::IntervalSpec.new(
              interval: Internal::ProtoUtils.seconds_to_duration(every),
              phase: Internal::ProtoUtils.seconds_to_duration(offset)
            )
          end
        end
      end

      Range = Data.define(
        :start,
        :finish,
        :step
      )

      # Inclusive range for a schedule match value.
      #
      # @!attribute start
      #   @return [Integer] Inclusive start of the range.
      # @!attribute finish
      #   @return [Integer] Inclusive end of the range. If unset or less than start, defaults to start.
      # @!attribute step
      #   @return [Integer] Step to take between each value. Defaults as 1.
      class Range
        class << self
          alias _original_new new

          # Create inclusive range.
          #
          # @param start [Integer] Inclusive start of the range.
          # @param finish [Integer] Inclusive end of the range. If unset or less than start, defaults to start.
          # @param step [Integer] Step to take between each value. Defaults as 1.
          def new(start, finish = [0, start].max, step = 1)
            _original_new( # steep:ignore
              start:,
              finish:,
              step:
            )
          end
        end

        # @!visibility private
        def self._from_proto(raw_range)
          Schedule::Range.new(
            raw_range.start,
            raw_range.end,
            raw_range.step
          )
        end

        # @!visibility private
        def self._from_protos(raw_ranges)
          raw_ranges.map { |v| _from_proto(v) }
        end

        # @!visibility private
        def self._to_protos(ranges)
          ranges.map(&:_to_proto)
        end

        # @!visibility private
        def _to_proto
          Api::Schedule::V1::Range.new(
            start:,
            end: finish,
            step:
          )
        end
      end

      Policy = Data.define(
        :overlap,
        :catchup_window,
        :pause_on_failure
      )

      # Policies of a schedule.
      #
      # @!attribute overlap
      #   @return [OverlapPolicy] Controls what happens when an action is started while another is still running.
      # @!attribute catchup_window
      #   @return [Float] After a Temporal server is unavailable, amount of time in the past to execute missed actions.
      # @!attribute pause_on_failure
      #   @return [Boolean] Whether to pause the schedule if an action fails or times out. Note: For workflows, this
      #     only applies after all retries have been exhausted.
      class Policy
        # @!visibility private
        def self._from_proto(raw_policies)
          Schedule::Policy.new(
            overlap: Internal::ProtoUtils.enum_to_int(Api::Enums::V1::ScheduleOverlapPolicy,
                                                      raw_policies.overlap_policy,
                                                      zero_means_nil: true),
            catchup_window: Internal::ProtoUtils.duration_to_seconds(raw_policies.catchup_window) || raise, # Never nil
            pause_on_failure: raw_policies.pause_on_failure
          )
        end

        # Create a schedule policy.
        #
        # @param overlap [OverlapPolicy] Controls what happens when an action is started while another is still running.
        # @param catchup_window [Float] After a Temporal server is unavailable, amount of time in the past to execute
        #   missed actions.
        # @param pause_on_failure [Boolean] Whether to pause the schedule if an action fails or times out. Note: For
        #   workflows, this only applies after all retries have been exhausted.
        def initialize(
          overlap: OverlapPolicy::SKIP,
          catchup_window: 365 * 24 * 60 * 60.0,
          pause_on_failure: false
        )
          super
        end

        # @!visibility private
        def _to_proto
          Api::Schedule::V1::SchedulePolicies.new(
            overlap_policy: overlap,
            catchup_window: Internal::ProtoUtils.seconds_to_duration(catchup_window),
            pause_on_failure:
          )
        end
      end

      State = Data.define(
        :note,
        :paused,
        :limited_actions,
        :remaining_actions
      )

      # State of a schedule.
      #
      # @!attribute note
      #   @return [String, nil] Human readable message for the schedule. The system may overwrite this value on certain
      #     conditions like pause-on-failure.
      # @!attribute paused
      #   @return [Boolean] Whether the schedule is paused.
      # @!attribute limited_actions
      #   @return [Boolean] If true, remaining actions will be decremented for each action taken. On schedule create,
      #     this must be set to true if `remaining_actions` is non-zero and left false if `remaining_actions` is zero.
      # @!attribute remaining_actions
      #   @return [Integer] Actions remaining on this schedule. Once this number hits 0, no further actions are
      #     scheduled automatically.
      class State
        # @!visibility private
        def self._from_proto(raw_state)
          Schedule::State.new(
            note: Internal::ProtoUtils.string_or(raw_state.notes),
            paused: raw_state.paused,
            limited_actions: raw_state.limited_actions,
            remaining_actions: raw_state.remaining_actions
          )
        end

        # Create a schedule state.
        #
        # @param note [String, nil] Human readable message for the schedule. The system may overwrite this value on
        #   certain conditions like pause-on-failure.
        # @param paused [Boolean] Whether the schedule is paused.
        # @param limited_actions [Boolean] If true, remaining actions will be decremented for each action taken. On
        #   schedule create, this must be set to true if `remaining_actions` is non-zero and left false if
        #   `remaining_actions` is zero.
        # @param remaining_actions [Integer] Actions remaining on this schedule. Once this number hits 0, no further
        #   actions are scheduled automatically.
        def initialize(
          note: nil,
          paused: false,
          limited_actions: false,
          remaining_actions: 0
        )
          super
        end

        # @!visibility private
        def _to_proto
          Api::Schedule::V1::ScheduleState.new(
            notes: note || '',
            paused:,
            limited_actions:,
            remaining_actions:
          )
        end
      end

      Update = Data.define(
        :schedule,
        :search_attributes
      )

      # Result of an update callback for {ScheduleHandle.update}.
      #
      # @!attribute schedule
      #   @return [Schedule] Schedule to update.
      # @!attribute search_attributes
      #   @return [SearchAttributes, nil] Search attributes to update to.
      class Update
        # Create an update callback result.
        #
        # @param schedule [Schedule] Schedule to update.
        # @param search_attributes [SearchAttributes, nil] Search attributes to update to.
        def initialize(schedule:, search_attributes: nil)
          super
        end

        # Parameter for an update callback for {ScheduleHandle.update}.
        #
        # @!attribute description
        #   @return [Description] Current description of the schedule.
        Input = Data.define( # rubocop:disable Layout/ClassStructure
          :description
        )
      end

      module List
        Description = Data.define(
          :id,
          :schedule,
          :info,
          :raw_entry
        )

        # Description of a listed schedule.
        #
        # @!attribute id
        #   @return [String] ID of the schedule.
        # @!attribute schedule
        #   @return [Schedule, nil] Schedule details that can be mutated. This may not be present in older Temporal
        #     servers without advanced visibility.
        # @!attribute info
        #   @return [Info, nil] Information about the schedule. This may not be present in older Temporal servers
        #     without advanced visibility.
        # @!attribute raw_entry
        #   @return [Api::Schedule::V1::ScheduleListEntry] Raw description of the schedule.
        class Description
          # @!visibility private
          def initialize(raw_entry:, data_converter:)
            @memo = Internal::ProtoUtils::LazyMemo.new(raw_entry.memo, data_converter)
            @search_attributes = Internal::ProtoUtils::LazySearchAttributes.new(raw_entry.search_attributes)
            # steep:ignore:start
            super(
              id: raw_entry.schedule_id,
              schedule: (Schedule.new(raw_info: raw_entry.info) if raw_entry.info),
              info: (Info.new(raw_info: raw_entry.info) if raw_entry.info),
              raw_entry:
            )
            # steep:ignore:end
          end

          # @return [Hash<String, Object>, nil] Memo for the schedule, converted lazily on first call.
          def memo
            @memo.get
          end

          # @return [Search attributes, nil] Search attributes for the schedule, converted lazily on first call.
          def search_attributes
            @search_attributes.get
          end
        end

        Schedule = Data.define(
          :action,
          :spec,
          :state
        )

        # Details for a listed schedule.
        #
        # @!attribute action
        #   @return [Action] Action taken when scheduled.
        # @!attribute spec
        #   @return [Spec] When the action is taken.
        # @!attribute state
        #   @return [State] State of the schedule.
        class Schedule
          # @!visibility private
          def initialize(raw_info:)
            raise 'Unknown action on schedule' unless raw_info.workflow_type

            # steep:ignore:start
            super(
              action: Action::StartWorkflow.new(workflow: raw_info.workflow_type.name),
              spec: Spec._from_proto(raw_info.spec),
              state: State.new(raw_info:)
            )
            # steep:ignore:end
          end
        end

        # Base module mixed in by specific actions a listed schedule can take.
        module Action
          StartWorkflow = Data.define(
            :workflow
          )

          # Action to start a workflow on a listed schedule.
          #
          # @!attribute workflow
          #   @return [String] Workflow type name.
          class StartWorkflow
            include Action
          end
        end

        Info = Data.define(
          :recent_actions,
          :next_action_times
        )

        # Information about a listed schedule.
        #
        # @!attribute recent_actions
        #   @return [Array<ActionResult>] Most recent actions, oldest first. This may be a smaller amount than present
        #     on {Temporalio::Client::Schedule::Info.recent_actions}.
        # @!attribute next_action_times
        #   @return [Array<Time>] Next scheduled action times. This may be a smaller amount than present on
        #     {Temporalio::Client::Schedule::Info.next_action_times}.
        class Info
          # @!visibility private
          def initialize(raw_info:)
            # steep:ignore:start
            super(
              recent_actions: raw_info.recent_actions.map { |a| ActionResult.new(raw_result: a) },
              next_action_times: raw_info.future_action_times.map { |t| Internal::ProtoUtils.timestamp_to_time(t) }
            )
            # steep:ignore:end
          end
        end

        State = Data.define(
          :note,
          :paused
        )

        # State of a listed schedule.
        #
        # @!attribute note
        #   @return [String, nil] Human readable message for the schedule. The system may overwrite this value on
        #     certain conditions like pause-on-failure.
        # @!attribute paused
        #   @return [Boolean] Whether the schedule is paused.
        class State
          # @!visibility private
          def initialize(raw_info:)
            # steep:ignore:start
            super(
              note: Internal::ProtoUtils.string_or(raw_info.notes),
              paused: raw_info.paused
            )
            # steep:ignore:end
          end
        end
      end
    end
  end
end
