# typed: true

class Temporalio::Client::Schedule < ::Data
  sig do
    params(
      action: Temporalio::Client::Schedule::Action,
      spec: Temporalio::Client::Schedule::Spec,
      policy: Temporalio::Client::Schedule::Policy,
      state: Temporalio::Client::Schedule::State
    ).void
  end
  def initialize(action:, spec:, policy: T.unsafe(nil), state: T.unsafe(nil)); end

  sig { returns(Temporalio::Client::Schedule::Action) }
  def action; end

  sig { returns(Temporalio::Client::Schedule::Spec) }
  def spec; end

  sig { returns(Temporalio::Client::Schedule::Policy) }
  def policy; end

  sig { returns(Temporalio::Client::Schedule::State) }
  def state; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Client::Schedule) }
  def with(**kwargs); end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

module Temporalio::Client::Schedule::Action; end

class Temporalio::Client::Schedule::Action::StartWorkflow < ::Data
  include Temporalio::Client::Schedule::Action

  sig { returns(T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String)) }
  def workflow; end

  sig { returns(T::Array[T.nilable(Object)]) }
  def args; end

  sig { returns(String) }
  def id; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(T.nilable(String)) }
  def static_summary; end

  sig { returns(T.nilable(String)) }
  def static_details; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def execution_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def run_timeout; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def task_timeout; end

  sig { returns(T.nilable(Temporalio::RetryPolicy)) }
  def retry_policy; end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  sig { returns(Temporalio::Priority) }
  def priority; end

  sig { returns(T.nilable(T::Array[Object])) }
  def arg_hints; end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def headers; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Client::Schedule::Action::StartWorkflow) }
  def with(**kwargs); end

  class << self
    sig do
      params(
        workflow: T.any(T.class_of(Temporalio::Workflow::Definition), Temporalio::Workflow::Definition::Info, Symbol, String),
        args: T.nilable(Object),
        id: String,
        task_queue: String,
        static_summary: T.nilable(String),
        static_details: T.nilable(String),
        execution_timeout: T.nilable(T.any(Integer, Float)),
        run_timeout: T.nilable(T.any(Integer, Float)),
        task_timeout: T.nilable(T.any(Integer, Float)),
        retry_policy: T.nilable(Temporalio::RetryPolicy),
        memo: T.nilable(T::Hash[String, T.nilable(Object)]),
        search_attributes: T.nilable(Temporalio::SearchAttributes),
        priority: Temporalio::Priority,
        arg_hints: T.nilable(T::Array[Object]),
        headers: T.nilable(T::Hash[String, T.nilable(Object)])
      ).returns(Temporalio::Client::Schedule::Action::StartWorkflow)
    end
    def new(workflow, *args, id:, task_queue:, static_summary: T.unsafe(nil), static_details: T.unsafe(nil), execution_timeout: T.unsafe(nil), run_timeout: T.unsafe(nil), task_timeout: T.unsafe(nil), retry_policy: T.unsafe(nil), memo: T.unsafe(nil), search_attributes: T.unsafe(nil), priority: T.unsafe(nil), arg_hints: T.unsafe(nil), headers: T.unsafe(nil)); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Action::StartWorkflow) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

module Temporalio::Client::Schedule::OverlapPolicy
  SKIP = T.let(T.unsafe(nil), Integer)
  BUFFER_ONE = T.let(T.unsafe(nil), Integer)
  BUFFER_ALL = T.let(T.unsafe(nil), Integer)
  CANCEL_OTHER = T.let(T.unsafe(nil), Integer)
  TERMINATE_OTHER = T.let(T.unsafe(nil), Integer)
  ALLOW_ALL = T.let(T.unsafe(nil), Integer)
end

class Temporalio::Client::Schedule::Backfill < ::Data
  sig { params(start_at: Time, end_at: Time, overlap: T.nilable(Integer)).void }
  def initialize(start_at:, end_at:, overlap: T.unsafe(nil)); end

  sig { returns(Time) }
  def start_at; end

  sig { returns(Time) }
  def end_at; end

  sig { returns(T.nilable(Integer)) }
  def overlap; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Backfill) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Backfill) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

module Temporalio::Client::Schedule::ActionExecution; end

class Temporalio::Client::Schedule::ActionExecution::StartWorkflow < ::Data
  include Temporalio::Client::Schedule::ActionExecution

  sig { params(raw_execution: Temporalio::Api::Common::V1::WorkflowExecution).void }
  def initialize(raw_execution:); end

  sig { returns(String) }
  def workflow_id; end

  sig { returns(String) }
  def first_execution_run_id; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::ActionExecution::StartWorkflow) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::ActionExecution::StartWorkflow) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::ActionResult < ::Data
  sig { params(raw_result: Temporalio::Api::Schedule::V1::ScheduleActionResult).void }
  def initialize(raw_result:); end

  sig { returns(Time) }
  def scheduled_at; end

  sig { returns(Time) }
  def started_at; end

  sig { returns(Temporalio::Client::Schedule::ActionExecution) }
  def action; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::ActionResult) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::ActionResult) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::Spec < ::Data
  sig do
    params(
      calendars: T::Array[Temporalio::Client::Schedule::Spec::Calendar],
      intervals: T::Array[Temporalio::Client::Schedule::Spec::Interval],
      cron_expressions: T::Array[String],
      skip: T::Array[Temporalio::Client::Schedule::Spec::Calendar],
      start_at: T.nilable(Time),
      end_at: T.nilable(Time),
      jitter: T.nilable(Float),
      time_zone_name: T.nilable(String)
    ).void
  end
  def initialize(
    calendars: T.unsafe(nil),
    intervals: T.unsafe(nil),
    cron_expressions: T.unsafe(nil),
    skip: T.unsafe(nil),
    start_at: T.unsafe(nil),
    end_at: T.unsafe(nil),
    jitter: T.unsafe(nil),
    time_zone_name: T.unsafe(nil)
  ); end

  sig { returns(T::Array[Temporalio::Client::Schedule::Spec::Calendar]) }
  def calendars; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Spec::Interval]) }
  def intervals; end

  sig { returns(T::Array[String]) }
  def cron_expressions; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Spec::Calendar]) }
  def skip; end

  sig { returns(T.nilable(Time)) }
  def start_at; end

  sig { returns(T.nilable(Time)) }
  def end_at; end

  sig { returns(T.nilable(Numeric)) }
  def jitter; end

  sig { returns(T.nilable(String)) }
  def time_zone_name; end

  sig { params(kwargs: T.untyped).returns(Temporalio::Client::Schedule::Spec) }
  def with(**kwargs); end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::Spec::Calendar < ::Data
  sig do
    params(
      second: T::Array[Temporalio::Client::Schedule::Range],
      minute: T::Array[Temporalio::Client::Schedule::Range],
      hour: T::Array[Temporalio::Client::Schedule::Range],
      day_of_month: T::Array[Temporalio::Client::Schedule::Range],
      month: T::Array[Temporalio::Client::Schedule::Range],
      year: T::Array[Temporalio::Client::Schedule::Range],
      day_of_week: T::Array[Temporalio::Client::Schedule::Range],
      comment: T.nilable(String)
    ).void
  end
  def initialize(
    second: T.unsafe(nil),
    minute: T.unsafe(nil),
    hour: T.unsafe(nil),
    day_of_month: T.unsafe(nil),
    month: T.unsafe(nil),
    year: T.unsafe(nil),
    day_of_week: T.unsafe(nil),
    comment: T.unsafe(nil)
  ); end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def second; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def minute; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def hour; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def day_of_month; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def month; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def year; end

  sig { returns(T::Array[Temporalio::Client::Schedule::Range]) }
  def day_of_week; end

  sig { returns(T.nilable(String)) }
  def comment; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec::Calendar) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec::Calendar) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::Spec::Interval < ::Data
  sig { params(every: T.any(Integer, Float), offset: T.nilable(T.any(Integer, Float))).void }
  def initialize(every:, offset: T.unsafe(nil)); end

  sig { returns(T.any(Integer, Float)) }
  def every; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def offset; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec::Interval) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Spec::Interval) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::Range < ::Data
  sig { returns(Integer) }
  def start; end

  sig { returns(Integer) }
  def finish; end

  sig { returns(Integer) }
  def step; end

  class << self
    sig { params(start: Integer, finish: Integer, step: Integer).returns(Temporalio::Client::Schedule::Range) }
    def new(start, finish = T.unsafe(nil), step = T.unsafe(nil)); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Range) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::Policy < ::Data
  sig do
    params(
      overlap: Integer,
      catchup_window: T.nilable(T.any(Integer, Float)),
      pause_on_failure: T::Boolean
    ).void
  end
  def initialize(overlap: T.unsafe(nil), catchup_window: T.unsafe(nil), pause_on_failure: T.unsafe(nil)); end

  sig { returns(Integer) }
  def overlap; end

  sig { returns(T.nilable(T.any(Integer, Float))) }
  def catchup_window; end

  sig { returns(T::Boolean) }
  def pause_on_failure; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Policy) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Policy) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::State < ::Data
  sig do
    params(
      note: T.nilable(String),
      paused: T::Boolean,
      limited_actions: T::Boolean,
      remaining_actions: Integer
    ).void
  end
  def initialize(note: T.unsafe(nil), paused: T.unsafe(nil), limited_actions: T.unsafe(nil), remaining_actions: T.unsafe(nil)); end

  sig { returns(T.nilable(String)) }
  def note; end

  sig { returns(T::Boolean) }
  def paused; end

  sig { returns(T::Boolean) }
  def limited_actions; end

  sig { returns(Integer) }
  def remaining_actions; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::State) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::State) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::Description < ::Data
  sig { params(id: String, raw_description: Temporalio::Api::WorkflowService::V1::DescribeScheduleResponse, data_converter: Temporalio::Converters::DataConverter).void }
  def initialize(id:, raw_description:, data_converter:); end

  sig { returns(String) }
  def id; end

  sig { returns(Temporalio::Client::Schedule) }
  def schedule; end

  sig { returns(Temporalio::Client::Schedule::Info) }
  def info; end

  sig { returns(Temporalio::Api::WorkflowService::V1::DescribeScheduleResponse) }
  def raw_description; end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Description) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Description) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::Info < ::Data
  sig { params(raw_info: Temporalio::Api::Schedule::V1::ScheduleInfo).void }
  def initialize(raw_info:); end

  sig { returns(Integer) }
  def num_actions; end

  sig { returns(Integer) }
  def num_actions_missed_catchup_window; end

  sig { returns(Integer) }
  def num_actions_skipped_overlap; end

  sig { returns(T::Array[Temporalio::Client::Schedule::ActionExecution]) }
  def running_actions; end

  sig { returns(T::Array[Temporalio::Client::Schedule::ActionResult]) }
  def recent_actions; end

  sig { returns(T::Array[Time]) }
  def next_action_times; end

  sig { returns(Time) }
  def created_at; end

  sig { returns(T.nilable(Time)) }
  def last_updated_at; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Info) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Info) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::Update < ::Data
  sig { params(schedule: Temporalio::Client::Schedule, search_attributes: T.nilable(Temporalio::SearchAttributes)).void }
  def initialize(schedule:, search_attributes: T.unsafe(nil)); end

  sig { returns(Temporalio::Client::Schedule) }
  def schedule; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Update) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Update) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::Update::Input < ::Data
  sig { returns(Temporalio::Client::Schedule::Description) }
  def description; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Update::Input) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::Update::Input) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

module Temporalio::Client::Schedule::List; end

module Temporalio::Client::Schedule::List::Action; end

class Temporalio::Client::Schedule::List::Action::StartWorkflow < ::Data
  include Temporalio::Client::Schedule::List::Action

  sig { returns(String) }
  def workflow; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Action::StartWorkflow) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Action::StartWorkflow) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::List::Description < ::Data
  sig { params(raw_entry: Temporalio::Api::Schedule::V1::ScheduleListEntry, data_converter: Temporalio::Converters::DataConverter).void }
  def initialize(raw_entry:, data_converter:); end

  sig { returns(String) }
  def id; end

  sig { returns(Temporalio::Client::Schedule::List::Schedule) }
  def schedule; end

  sig { returns(Temporalio::Client::Schedule::List::Info) }
  def info; end

  sig { returns(Temporalio::Api::Schedule::V1::ScheduleListEntry) }
  def raw_entry; end

  sig { returns(T.nilable(T::Hash[String, T.nilable(Object)])) }
  def memo; end

  sig { returns(T.nilable(Temporalio::SearchAttributes)) }
  def search_attributes; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Description) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Description) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::List::Schedule < ::Data
  sig { params(raw_info: Temporalio::Api::Schedule::V1::ScheduleListInfo).void }
  def initialize(raw_info:); end

  sig { returns(Temporalio::Client::Schedule::List::Action) }
  def action; end

  sig { returns(Temporalio::Client::Schedule::Spec) }
  def spec; end

  sig { returns(Temporalio::Client::Schedule::List::State) }
  def state; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Schedule) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Schedule) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::List::Info < ::Data
  sig { params(raw_info: Temporalio::Api::Schedule::V1::ScheduleListInfo).void }
  def initialize(raw_info:); end

  sig { returns(T::Array[Temporalio::Client::Schedule::ActionResult]) }
  def recent_actions; end

  sig { returns(T::Array[Time]) }
  def next_action_times; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Info) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::Info) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end

class Temporalio::Client::Schedule::List::State < ::Data
  sig { params(raw_info: Temporalio::Api::Schedule::V1::ScheduleListInfo).void }
  def initialize(raw_info:); end

  sig { returns(T.nilable(String)) }
  def note; end

  sig { returns(T::Boolean) }
  def paused; end

  class << self
    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::State) }
    def new(*args); end

    sig { params(args: T.untyped).returns(Temporalio::Client::Schedule::List::State) }
    def [](*args); end

    sig { returns(T::Array[Symbol]) }
    def members; end
  end
end
