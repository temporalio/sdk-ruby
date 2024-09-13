# frozen_string_literal: true

require 'temporalio/internal/bridge'
require 'temporalio/temporalio_bridge'

module Temporalio
  module Internal
    module Bridge
      class Worker
        Options = Struct.new(
          :activity,
          :workflow,
          :namespace,
          :task_queue,
          :tuner,
          :build_id,
          :identity_override,
          :max_cached_workflows,
          :max_concurrent_workflow_task_polls,
          :nonsticky_to_sticky_poll_ratio,
          :max_concurrent_activity_task_polls,
          :no_remote_activities,
          :sticky_queue_schedule_to_start_timeout,
          :max_heartbeat_throttle_interval,
          :default_heartbeat_throttle_interval,
          :max_worker_activities_per_second,
          :max_task_queue_activities_per_second,
          :graceful_shutdown_period,
          :use_worker_versioning,
          keyword_init: true
        )

        TunerOptions = Struct.new(
          :workflow_slot_supplier,
          :activity_slot_supplier,
          :local_activity_slot_supplier,
          keyword_init: true
        )

        TunerSlotSupplierOptions = Struct.new(
          :fixed_size,
          :resource_based,
          keyword_init: true
        )

        TunerResourceBasedSlotSupplierOptions = Struct.new(
          :target_mem_usage,
          :target_cpu_usage,
          :min_slots,
          :max_slots,
          :ramp_throttle,
          keyword_init: true
        )

        def self.finalize_shutdown_all(workers)
          Bridge.async_call do |queue|
            async_finalize_all(workers) do |val|
              queue.push(val)
            end
          end
        end

        def validate
          Bridge.async_call do |queue|
            async_validate do |val|
              queue.push(val)
            end
          end
        end

        def complete_activity_task(proto)
          Bridge.async_call do |queue|
            async_complete_activity_task(proto.to_proto) do |val|
              queue.push(val)
            end
          end
        end

        def complete_activity_task_in_background(proto)
          async_complete_activity_task(proto.to_proto) do |val|
            unless val.nil?
              warn('Failed completing activity task in background')
              warn(val)
            end
          end
        end
      end
    end
  end
end
