# typed: true

class Temporalio::Internal::Bridge::Worker
  extend T::Sig

  sig { params(workers: T::Array[Temporalio::Internal::Bridge::Worker]).void }
  def self.finalize_shutdown_all(workers); end

  sig { void }
  def validate; end

  sig { params(proto: Object).void }
  def complete_activity_task(proto); end

  sig { params(proto: Object).void }
  def complete_activity_task_in_background(proto); end

  sig do
    params(
      client: Temporalio::Internal::Bridge::Client,
      options: Temporalio::Internal::Bridge::Worker::Options
    ).returns(Temporalio::Internal::Bridge::Worker)
  end
  def self.new(client, options); end

  sig { params(workers: T::Array[Temporalio::Internal::Bridge::Worker], queue: Queue).void }
  def self.async_poll_all(workers, queue); end

  sig { params(workers: T::Array[Temporalio::Internal::Bridge::Worker], queue: Queue).void }
  def self.async_finalize_all(workers, queue); end

  sig { params(queue: Queue).void }
  def async_validate(queue); end

  sig { params(proto: String, queue: Queue).void }
  def async_complete_activity_task(proto, queue); end

  sig { params(run_id: String, proto: String, queue: Queue).void }
  def async_complete_workflow_activation(run_id, proto, queue); end

  sig { params(proto: String).void }
  def record_activity_heartbeat(proto); end

  sig { params(client: Temporalio::Internal::Bridge::Client).void }
  def replace_client(client); end

  sig { void }
  def initiate_shutdown; end
end

class Temporalio::Internal::Bridge::Worker::Options < ::Struct
  extend T::Sig

  sig do
    params(
      namespace: String,
      task_queue: String,
      tuner: Temporalio::Internal::Bridge::Worker::TunerOptions,
      identity_override: T.nilable(String),
      max_cached_workflows: Integer,
      workflow_task_poller_behavior: T.any(
        Temporalio::Internal::Bridge::Worker::PollerBehaviorSimpleMaximum,
        Temporalio::Internal::Bridge::Worker::PollerBehaviorAutoscaling
      ),
      nonsticky_to_sticky_poll_ratio: T.any(Integer, Float),
      activity_task_poller_behavior: T.any(
        Temporalio::Internal::Bridge::Worker::PollerBehaviorSimpleMaximum,
        Temporalio::Internal::Bridge::Worker::PollerBehaviorAutoscaling
      ),
      enable_workflows: T::Boolean,
      enable_local_activities: T::Boolean,
      enable_remote_activities: T::Boolean,
      enable_nexus: T::Boolean,
      sticky_queue_schedule_to_start_timeout: T.any(Integer, Float),
      max_heartbeat_throttle_interval: T.any(Integer, Float),
      default_heartbeat_throttle_interval: T.any(Integer, Float),
      max_worker_activities_per_second: T.nilable(T.any(Integer, Float)),
      max_task_queue_activities_per_second: T.nilable(T.any(Integer, Float)),
      graceful_shutdown_period: T.any(Integer, Float),
      nondeterminism_as_workflow_fail: T::Boolean,
      nondeterminism_as_workflow_fail_for_types: T::Array[String],
      deployment_options: T.nilable(Temporalio::Internal::Bridge::Worker::DeploymentOptions),
      plugins: T::Array[String]
    ).void
  end
  def initialize(
    namespace,
    task_queue,
    tuner,
    identity_override,
    max_cached_workflows,
    workflow_task_poller_behavior,
    nonsticky_to_sticky_poll_ratio,
    activity_task_poller_behavior,
    enable_workflows,
    enable_local_activities,
    enable_remote_activities,
    enable_nexus,
    sticky_queue_schedule_to_start_timeout,
    max_heartbeat_throttle_interval,
    default_heartbeat_throttle_interval,
    max_worker_activities_per_second,
    max_task_queue_activities_per_second,
    graceful_shutdown_period,
    nondeterminism_as_workflow_fail,
    nondeterminism_as_workflow_fail_for_types,
    deployment_options,
    plugins
  ); end
end

class Temporalio::Internal::Bridge::Worker::TunerOptions < ::Struct
  extend T::Sig

  sig do
    params(
      workflow_slot_supplier: Temporalio::Internal::Bridge::Worker::TunerSlotSupplierOptions,
      activity_slot_supplier: Temporalio::Internal::Bridge::Worker::TunerSlotSupplierOptions,
      local_activity_slot_supplier: Temporalio::Internal::Bridge::Worker::TunerSlotSupplierOptions
    ).void
  end
  def initialize(workflow_slot_supplier, activity_slot_supplier, local_activity_slot_supplier); end
end

class Temporalio::Internal::Bridge::Worker::TunerSlotSupplierOptions < ::Struct
  extend T::Sig

  sig do
    params(
      fixed_size: T.nilable(Integer),
      resource_based: T.nilable(Temporalio::Internal::Bridge::Worker::TunerResourceBasedSlotSupplierOptions),
      custom: T.nilable(Temporalio::Internal::Bridge::Worker::CustomSlotSupplier)
    ).void
  end
  def initialize(fixed_size, resource_based, custom); end
end

class Temporalio::Internal::Bridge::Worker::TunerResourceBasedSlotSupplierOptions < ::Struct
  extend T::Sig

  sig do
    params(
      target_mem_usage: T.any(Integer, Float),
      target_cpu_usage: T.any(Integer, Float),
      min_slots: T.nilable(Integer),
      max_slots: T.nilable(Integer),
      ramp_throttle: T.nilable(T.any(Integer, Float))
    ).void
  end
  def initialize(target_mem_usage, target_cpu_usage, min_slots, max_slots, ramp_throttle); end
end

class Temporalio::Internal::Bridge::Worker::CustomSlotSupplier
  extend T::Sig

  sig do
    params(
      slot_supplier: Temporalio::Worker::Tuner::SlotSupplier::Custom,
      thread_pool: T.nilable(Temporalio::Worker::ThreadPool)
    ).void
  end
  def initialize(slot_supplier:, thread_pool:); end

  sig do
    params(
      context: Temporalio::Worker::Tuner::SlotSupplier::Custom::ReserveContext,
      cancellation: Temporalio::Cancellation,
      block: T.proc.params(arg0: Object).void
    ).void
  end
  def reserve_slot(context, cancellation, &block); end

  sig do
    params(
      context: Temporalio::Worker::Tuner::SlotSupplier::Custom::ReserveContext,
      block: T.proc.params(arg0: Object).void
    ).void
  end
  def try_reserve_slot(context, &block); end

  sig do
    params(
      context: Temporalio::Worker::Tuner::SlotSupplier::Custom::MarkUsedContext,
      block: T.proc.params(arg0: Object).void
    ).void
  end
  def mark_slot_used(context, &block); end

  sig do
    params(
      context: Temporalio::Worker::Tuner::SlotSupplier::Custom::ReleaseContext,
      block: T.proc.params(arg0: Object).void
    ).void
  end
  def release_slot(context, &block); end

  private

  sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
  def run_user_code(&block); end
end

class Temporalio::Internal::Bridge::Worker::WorkerDeploymentVersion < ::Struct
  extend T::Sig

  sig { params(deployment_name: String, build_id: String).void }
  def initialize(deployment_name, build_id); end
end

class Temporalio::Internal::Bridge::Worker::DeploymentOptions < ::Struct
  extend T::Sig

  sig do
    params(
      version: Temporalio::Internal::Bridge::Worker::WorkerDeploymentVersion,
      use_worker_versioning: T::Boolean,
      default_versioning_behavior: Integer
    ).void
  end
  def initialize(version, use_worker_versioning, default_versioning_behavior); end
end

class Temporalio::Internal::Bridge::Worker::PollerBehaviorSimpleMaximum < ::Struct
  extend T::Sig

  sig { params(simple_maximum: Integer).void }
  def initialize(simple_maximum); end
end

class Temporalio::Internal::Bridge::Worker::PollerBehaviorAutoscaling < ::Struct
  extend T::Sig

  sig { params(minimum: Integer, maximum: Integer, initial: Integer).void }
  def initialize(minimum, maximum, initial); end
end

class Temporalio::Internal::Bridge::Worker::WorkflowReplayer
  extend T::Sig

  sig do
    params(
      runtime: Temporalio::Internal::Bridge::Runtime,
      options: Temporalio::Internal::Bridge::Worker::Options
    ).returns([Temporalio::Internal::Bridge::Worker::WorkflowReplayer, Temporalio::Internal::Bridge::Worker])
  end
  def self.new(runtime, options); end

  sig { params(workflow_id: String, proto: String).void }
  def push_history(workflow_id, proto); end
end
