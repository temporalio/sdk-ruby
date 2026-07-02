# typed: true

class Temporalio::Worker::Tuner
  extend T::Sig

  sig { returns(SlotSupplier) }
  attr_reader :workflow_slot_supplier

  sig { returns(SlotSupplier) }
  attr_reader :activity_slot_supplier

  sig { returns(SlotSupplier) }
  attr_reader :local_activity_slot_supplier

  sig { returns(T.nilable(Temporalio::Worker::ThreadPool)) }
  attr_reader :custom_slot_supplier_thread_pool

  sig do
    params(
      workflow_slot_supplier: SlotSupplier,
      activity_slot_supplier: SlotSupplier,
      local_activity_slot_supplier: SlotSupplier,
      custom_slot_supplier_thread_pool: T.nilable(Temporalio::Worker::ThreadPool)
    ).void
  end
  def initialize(
    workflow_slot_supplier:,
    activity_slot_supplier:,
    local_activity_slot_supplier:,
    custom_slot_supplier_thread_pool: T.unsafe(nil)
  ); end

  class << self
    extend T::Sig

    sig do
      params(
        workflow_slots: Integer,
        activity_slots: Integer,
        local_activity_slots: Integer
      ).returns(Temporalio::Worker::Tuner)
    end
    def create_fixed(workflow_slots: T.unsafe(nil), activity_slots: T.unsafe(nil), local_activity_slots: T.unsafe(nil)); end

    sig do
      params(
        target_memory_usage: Float,
        target_cpu_usage: Float,
        workflow_options: ResourceBasedSlotOptions,
        activity_options: ResourceBasedSlotOptions,
        local_activity_options: ResourceBasedSlotOptions
      ).returns(Temporalio::Worker::Tuner)
    end
    def create_resource_based(
      target_memory_usage:,
      target_cpu_usage:,
      workflow_options: T.unsafe(nil),
      activity_options: T.unsafe(nil),
      local_activity_options: T.unsafe(nil)
    ); end
  end
end

class Temporalio::Worker::Tuner::SlotSupplier; end

class Temporalio::Worker::Tuner::SlotSupplier::Fixed < ::Temporalio::Worker::Tuner::SlotSupplier
  extend T::Sig

  sig { returns(Integer) }
  attr_reader :slots

  sig { params(slots: Integer).void }
  def initialize(slots); end
end

class Temporalio::Worker::Tuner::SlotSupplier::ResourceBased < ::Temporalio::Worker::Tuner::SlotSupplier
  extend T::Sig

  sig { returns(Temporalio::Worker::Tuner::ResourceBasedTunerOptions) }
  attr_reader :tuner_options

  sig { returns(Temporalio::Worker::Tuner::ResourceBasedSlotOptions) }
  attr_reader :slot_options

  sig do
    params(
      tuner_options: Temporalio::Worker::Tuner::ResourceBasedTunerOptions,
      slot_options: Temporalio::Worker::Tuner::ResourceBasedSlotOptions
    ).void
  end
  def initialize(tuner_options:, slot_options:); end
end

class Temporalio::Worker::Tuner::SlotSupplier::Custom < ::Temporalio::Worker::Tuner::SlotSupplier
  extend T::Sig

  sig do
    params(
      context: ReserveContext,
      cancellation: Temporalio::Cancellation,
      block: T.proc.params(arg0: Object).void
    ).void
  end
  def reserve_slot(context, cancellation, &block); end

  sig { params(context: ReserveContext).returns(Object) }
  def try_reserve_slot(context); end

  sig { params(context: MarkUsedContext).void }
  def mark_slot_used(context); end

  sig { params(context: ReleaseContext).void }
  def release_slot(context); end
end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::ReserveContext < ::Data
  extend T::Sig

  sig { returns(Symbol) }
  def slot_type; end

  sig { returns(String) }
  def task_queue; end

  sig { returns(String) }
  def worker_identity; end

  sig { returns(String) }
  def worker_deployment_name; end

  sig { returns(String) }
  def worker_build_id; end

  sig { returns(T::Boolean) }
  def sticky?; end
end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::MarkUsedContext < ::Data
  extend T::Sig

  sig { returns(T.any(Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Workflow, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Activity, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::LocalActivity, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Nexus)) }
  def slot_info; end

  sig { returns(Object) }
  def permit; end
end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::ReleaseContext < ::Data
  extend T::Sig

  sig { returns(T.nilable(T.any(Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Workflow, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Activity, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::LocalActivity, Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Nexus))) }
  def slot_info; end

  sig { returns(Object) }
  def permit; end
end

module Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo; end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Workflow < ::Data
  extend T::Sig

  sig { returns(String) }
  def workflow_type; end

  sig { returns(T::Boolean) }
  def sticky?; end
end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Activity < ::Data
  extend T::Sig

  sig { returns(String) }
  def activity_type; end
end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::LocalActivity < ::Data
  extend T::Sig

  sig { returns(String) }
  def activity_type; end
end

class Temporalio::Worker::Tuner::SlotSupplier::Custom::SlotInfo::Nexus < ::Data
  extend T::Sig

  sig { returns(String) }
  def service; end

  sig { returns(String) }
  def operation; end
end

class Temporalio::Worker::Tuner::ResourceBasedTunerOptions < ::Data
  extend T::Sig

  sig { returns(Float) }
  def target_memory_usage; end

  sig { returns(Float) }
  def target_cpu_usage; end

  sig { params(target_memory_usage: Float, target_cpu_usage: Float).void }
  def initialize(target_memory_usage:, target_cpu_usage:); end
end

class Temporalio::Worker::Tuner::ResourceBasedSlotOptions < ::Data
  extend T::Sig

  sig { returns(T.nilable(Integer)) }
  def min_slots; end

  sig { returns(T.nilable(Integer)) }
  def max_slots; end

  sig { returns(T.nilable(Numeric)) }
  def ramp_throttle; end

  sig { params(min_slots: T.nilable(Integer), max_slots: T.nilable(Integer), ramp_throttle: T.nilable(Float)).void }
  def initialize(min_slots:, max_slots:, ramp_throttle:); end
end
