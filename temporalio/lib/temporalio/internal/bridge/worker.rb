# frozen_string_literal: true

require 'temporalio/internal/bridge'

module Temporalio
  module Internal
    module Bridge
      class Worker
        Options = Struct.new(
          :namespace,
          :task_queue,
          :tuner,
          :identity_override,
          :max_cached_workflows,
          :workflow_task_poller_behavior,
          :nonsticky_to_sticky_poll_ratio,
          :activity_task_poller_behavior,
          :enable_workflows,
          :enable_local_activities,
          :enable_remote_activities,
          :enable_nexus,
          :sticky_queue_schedule_to_start_timeout,
          :max_heartbeat_throttle_interval,
          :default_heartbeat_throttle_interval,
          :max_worker_activities_per_second,
          :max_task_queue_activities_per_second,
          :graceful_shutdown_period,
          :nondeterminism_as_workflow_fail,
          :nondeterminism_as_workflow_fail_for_types,
          :deployment_options,
          :plugins,
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
          :custom,
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

        WorkerDeploymentVersion = Struct.new(
          :deployment_name,
          :build_id,
          keyword_init: true
        )

        DeploymentOptions = Struct.new(
          :version,
          :use_worker_versioning,
          :default_versioning_behavior,
          keyword_init: true
        )

        PollerBehaviorSimpleMaximum = Struct.new(
          :simple_maximum,
          keyword_init: true
        )

        PollerBehaviorAutoscaling = Struct.new(
          :minimum,
          :maximum,
          :initial,
          keyword_init: true
        )

        def self.finalize_shutdown_all(workers)
          queue = Queue.new
          async_finalize_all(workers, queue)
          result = queue.pop
          raise result if result.is_a?(Exception)
        end

        def validate
          queue = Queue.new
          async_validate(queue)
          result = queue.pop
          raise result if result.is_a?(Exception)
        end

        def complete_activity_task(proto)
          queue = Queue.new
          async_complete_activity_task(proto.to_proto, queue)
          result = queue.pop
          raise result if result.is_a?(Exception)
        end

        def complete_activity_task_in_background(proto)
          queue = Queue.new
          # TODO(cretz): Log error on this somehow?
          async_complete_activity_task(proto.to_proto, queue)
        end

        class CustomSlotSupplier
          def initialize(slot_supplier:, thread_pool:)
            @slot_supplier = slot_supplier
            @thread_pool = thread_pool
          end

          def reserve_slot(context, cancellation, &block)
            run_user_code do
              @slot_supplier.reserve_slot(context, cancellation) { |v| block.call(v) }
            rescue Exception => e # rubocop:disable Lint/RescueException
              block.call(e)
            end
          end

          def try_reserve_slot(context, &block)
            run_user_code do
              block.call(@slot_supplier.try_reserve_slot(context))
            rescue Exception => e # rubocop:disable Lint/RescueException
              block.call(e)
            end
          end

          def mark_slot_used(context, &block)
            run_user_code do
              block.call(@slot_supplier.mark_slot_used(context))
            rescue Exception => e # rubocop:disable Lint/RescueException
              block.call(e)
            end
          end

          def release_slot(context, &block)
            run_user_code do
              block.call(@slot_supplier.release_slot(context))
            rescue Exception => e # rubocop:disable Lint/RescueException
              block.call(e)
            end
          end

          private

          def run_user_code(&)
            if @thread_pool
              @thread_pool.execute(&)
            else
              yield
            end
          end
        end
      end
    end
  end
end
