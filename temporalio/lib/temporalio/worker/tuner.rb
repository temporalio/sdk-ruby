# frozen_string_literal: true

require 'temporalio/internal/bridge/worker'

module Temporalio
  class Worker
    # Worker tuner that allows for dynamic customization of some aspects of worker configuration.
    class Tuner
      # Slot supplier used for reserving slots for execution. Currently the only implementations allowed are {Fixed} and
      # {ResourceBased}.
      class SlotSupplier
        # A fixed-size slot supplier that will never issue more than a fixed number of slots.
        class Fixed < SlotSupplier
          # @return [Integer] The maximum number of slots that can be issued.
          attr_reader :slots

          # Create fixed-size slot supplier.
          #
          # @param slots [Integer] The maximum number of slots that can be issued.
          def initialize(slots) # rubocop:disable Lint/MissingSuper
            @slots = slots
          end

          # @!visibility private
          def _to_bridge_options(_tuner)
            Internal::Bridge::Worker::TunerSlotSupplierOptions.new(
              fixed_size: slots,
              resource_based: nil,
              custom: nil
            )
          end
        end

        # A slot supplier that will dynamically adjust the number of slots based on resource usage.
        class ResourceBased < SlotSupplier
          attr_reader :tuner_options, :slot_options

          # Create a resource-based slot supplier.
          #
          # @param tuner_options [ResourceBasedTunerOptions] General tuner options.
          # @param slot_options [ResourceBasedSlotOptions] Slot-supplier-specific tuner options.
          def initialize(tuner_options:, slot_options:) # rubocop:disable Lint/MissingSuper
            @tuner_options = tuner_options
            @slot_options = slot_options
          end

          # @!visibility private
          def _to_bridge_options(_tuner)
            Internal::Bridge::Worker::TunerSlotSupplierOptions.new(
              fixed_size: nil,
              resource_based: Internal::Bridge::Worker::TunerResourceBasedSlotSupplierOptions.new(
                target_mem_usage: tuner_options.target_memory_usage,
                target_cpu_usage: tuner_options.target_cpu_usage,
                min_slots: slot_options.min_slots,
                max_slots: slot_options.max_slots,
                ramp_throttle: slot_options.ramp_throttle
              ),
              custom: nil
            )
          end
        end

        # A slot supplier that has callbacks invoked to handle slot supplying.
        #
        # Users should be cautious when implementing this and make sure it is heavily tested and the documentation for
        # every method is well understood.
        class Custom < SlotSupplier
          # Context provided for slot reservation on custom slot supplier.
          #
          # @!attribute slot_type
          #   @return [:workflow, :activity, :local_activity, :nexus] Slot type.
          # @!attribute task_queue
          #   @return [String] Task queue.
          # @!attribute worker_identity
          #   @return [String] Worker identity.
          # @!attribute worker_deployment_name
          #   @return [String] Worker deployment name or empty string if not applicable.
          # @!attribute worker_build_id
          #   @return [String] Worker build ID or empty string if not applicable.
          # @!attribute sticky?
          #   @return [Boolean] True if this reservation is for a sticky workflow task.
          ReserveContext = Data.define(
            :slot_type,
            :task_queue,
            :worker_identity,
            :worker_deployment_name,
            :worker_build_id,
            :sticky?
          )

          # Context provided for marking a slot used.
          #
          # @!attribute slot_info
          #   @return [SlotInfo::Workflow, SlotInfo::Activity, SlotInfo::LocalActivity, SlotInfo::Nexus] Information
          #     about the slot. This is never nil.
          # @!attribute permit
          #   @return [Object] Object that was provided as the permit on reserve.
          MarkUsedContext = Data.define(
            :slot_info,
            :permit
          )

          # Context provided for releasing a slot.
          #
          # @!attribute slot_info
          #   @return [SlotInfo::Workflow, SlotInfo::Activity, SlotInfo::LocalActivity, SlotInfo::Nexus, nil]
          #     Information about the slot. This may be nil if the slot was never used.
          # @!attribute permit
          #   @return [Object] Object that was provided as the permit on reserve.
          ReleaseContext = Data.define(
            :slot_info,
            :permit
          )

          # Reserve a slot.
          #
          # This can/should block and must provide the permit to the (code) block. The permit is any object (including
          # nil) that will be given on the context for mark_slot_used and release_slot.
          #
          # Just returning from this call is not enough to reserve the slot, a permit must be provided to the block
          # (e.g. via yield or block.call). If the call completes, the system will still wait on the block (so this can
          # be backgrounded by passing the block to something else). Reservations may be canceled via the given
          # cancellation. Users can do things like add_cancel_callback, but it is very important that the code in the
          # callback is fast as it is run on the same reactor thread as many other Temporal Ruby worker calls.
          #
          # @note WARNING: This call should never raise an exception. Any exception raised is ignored and this is called
          #   again after 1 second.
          #
          # @param context [ReserveContext] Contextual information about this reserve call.
          # @param cancellation [Cancellation] Cancellation that is canceled when the reservation is no longer being
          #   asked for.
          # @yield [Object] Confirm reservation and provide a permit.
          def reserve_slot(context, cancellation, &)
            raise NotImplementedError
          end

          # Try to reserve a slot.
          #
          # @note WARNING: This should never block, this should return immediately with a permit, or nil if the
          #   reservation could not occur.
          #
          # @note WARNING: This call should never raise an exception. Any exception raised is ignored and the slot
          #   reservation attempt fails (i.e. same as if this method returned nil).
          #
          # @param context [ReserveContext] Contextual information about this reserve call.
          # @return [Object, nil] A non-nil object to perform the reservation successfully, a nil to fail the
          #   reservation.
          def try_reserve_slot(context)
            raise NotImplementedError
          end

          # Mark a slot as used.
          #
          # Due to the nature of Temporal polling, slots are reserved before they are used and may never get used. This
          # call is made as just a notification when a slot is actually used.
          #
          # @note WARNING: This should never block, this should return immediately.
          #
          # @note WARNING: This call should never raise an exception. Any exception raised is ignored.
          #
          # @param context [MarkUsedContext] Contextual information about this reserve call.
          def mark_slot_used(context)
            raise NotImplementedError
          end

          # Release a previously reserved slot.
          #
          # @note WARNING: This should never block, this should return immediately.
          #
          # @note WARNING: This call should never raise an exception. Any exception raised is ignored.
          #
          # @param context [ReleaseContext] Contextual information about this reserve call.
          def release_slot(context)
            raise NotImplementedError
          end

          # @!visibility private
          def _to_bridge_options(tuner)
            Internal::Bridge::Worker::TunerSlotSupplierOptions.new(
              fixed_size: nil,
              resource_based: nil,
              custom: Internal::Bridge::Worker::CustomSlotSupplier.new(
                slot_supplier: self,
                thread_pool: tuner.custom_slot_supplier_thread_pool
              )
            )
          end

          # Slot information.
          module SlotInfo
            # Information about a workflow slot.
            #
            # @!attribute workflow_type
            #   @return [String] Workflow type.
            # @!attribute sticky?
            #   @return [Boolean] Whether the slot was for a sticky task.
            Workflow = Data.define(:workflow_type, :sticky?)

            # Information about an activity slot.
            #
            # @!attribute activity_type
            #   @return [String] Activity type.
            Activity = Data.define(:activity_type)

            # Information about a local activity slot.
            #
            # @!attribute activity_type
            #   @return [String] Activity type.
            LocalActivity = Data.define(:activity_type)

            # Information about a Nexus slot.
            #
            # @!attribute service
            #   @return [String] Nexus service.
            # @!attribute operation
            #   @return [String] Nexus operation.
            Nexus = Data.define(:service, :operation)
          end
        end

        # @!visibility private
        def _to_bridge_options(_tuner)
          raise ArgumentError, 'Tuner slot suppliers must be instances of Fixed, ResourceBased, or Custom'
        end
      end

      # Options for {create_resource_based} or {SlotSupplier::ResourceBased}.
      #
      # @!attribute target_memory_usage
      #   @return [Float] A value between 0 and 1 that represents the target (system) memory usage. It's not recommended
      #     to set this higher than 0.8, since how much memory a workflow may use is not predictable, and you don't want
      #     to encounter OOM errors.
      # @!attribute target_cpu_usage
      #   @return [Float] A value between 0 and 1 that represents the target (system) CPU usage. This can be set to 1.0
      #     if desired, but it's recommended to leave some headroom for other processes.
      ResourceBasedTunerOptions = Data.define(
        :target_memory_usage,
        :target_cpu_usage
      )

      # Options for a specific slot type being used with {SlotSupplier::ResourceBased}.
      #
      # @!attribute min_slots
      #   @return [Integer, nil] Amount of slots that will be issued regardless of any other checks. Defaults to 5 for
      #     workflows and 1 for activities.
      # @!attribute max_slots
      #   @return [Integer, nil] Maximum amount of slots permitted. Defaults to 500.
      # @!attribute ramp_throttle
      #   @return [Float, nil] Minimum time we will wait (after passing the minimum slots number) between handing out
      #     new slots in seconds. Defaults to 0 for workflows and 0.05 for activities.
      #
      #     This value matters because how many resources a task will use cannot be determined ahead of time, and thus
      #     the system should wait to see how much resources are used before issuing more slots.
      ResourceBasedSlotOptions = Data.define(
        :min_slots,
        :max_slots,
        :ramp_throttle
      )

      # Create a fixed-size tuner with the provided number of slots.
      #
      # @param workflow_slots [Integer] Maximum number of workflow task slots.
      # @param activity_slots [Integer] Maximum number of activity slots.
      # @param local_activity_slots [Integer] Maximum number of local activity slots.
      # @return [Tuner] Created tuner.
      def self.create_fixed(
        workflow_slots: 100,
        activity_slots: 100,
        local_activity_slots: 100
      )
        new(
          workflow_slot_supplier: SlotSupplier::Fixed.new(workflow_slots),
          activity_slot_supplier: SlotSupplier::Fixed.new(activity_slots),
          local_activity_slot_supplier: SlotSupplier::Fixed.new(local_activity_slots)
        )
      end

      # Create a resource-based tuner with the provided options.
      #
      # @param target_memory_usage [Float] A value between 0 and 1 that represents the target (system) memory usage.
      #   It's not recommended to set this higher than 0.8, since how much memory a workflow may use is not predictable,
      #   and you don't want to encounter OOM errors.
      # @param target_cpu_usage [Float] A value between 0 and 1 that represents the target (system) CPU usage. This can
      #   be set to 1.0 if desired, but it's recommended to leave some headroom for other processes.
      # @param workflow_options [ResourceBasedSlotOptions] Resource-based options for workflow slot supplier.
      # @param activity_options [ResourceBasedSlotOptions] Resource-based options for activity slot supplier.
      # @param local_activity_options [ResourceBasedSlotOptions] Resource-based options for local activity slot
      #   supplier.
      # @return [Tuner] Created tuner.
      def self.create_resource_based(
        target_memory_usage:,
        target_cpu_usage:,
        workflow_options: ResourceBasedSlotOptions.new(min_slots: 5, max_slots: 500, ramp_throttle: 0.0),
        activity_options: ResourceBasedSlotOptions.new(min_slots: 1, max_slots: 500, ramp_throttle: 0.05),
        local_activity_options: ResourceBasedSlotOptions.new(min_slots: 1, max_slots: 500, ramp_throttle: 0.05)
      )
        tuner_options = ResourceBasedTunerOptions.new(target_memory_usage:, target_cpu_usage:)
        new(
          workflow_slot_supplier: SlotSupplier::ResourceBased.new(
            tuner_options:, slot_options: workflow_options
          ),
          activity_slot_supplier: SlotSupplier::ResourceBased.new(
            tuner_options:, slot_options: activity_options
          ),
          local_activity_slot_supplier: SlotSupplier::ResourceBased.new(
            tuner_options:, slot_options: local_activity_options
          )
        )
      end

      # @return [SlotSupplier] Slot supplier for workflows.
      attr_reader :workflow_slot_supplier

      # @return [SlotSupplier] Slot supplier for activities.
      attr_reader :activity_slot_supplier

      # @return [SlotSupplier] Slot supplier for local activities.
      attr_reader :local_activity_slot_supplier

      # @return [ThreadPool, nil] Thread pool for custom slot suppliers.
      attr_reader :custom_slot_supplier_thread_pool

      # Create a tuner from 3 slot suppliers.
      #
      # @param workflow_slot_supplier [SlotSupplier] Slot supplier for workflows.
      # @param activity_slot_supplier [SlotSupplier] Slot supplier for activities.
      # @param local_activity_slot_supplier [SlotSupplier] Slot supplier for local activities.
      # @param custom_slot_supplier_thread_pool [ThreadPool, nil] Thread pool to make all custom slot supplier calls on.
      #   If there are no custom slot suppliers, this parameter is ignored. Technically users may set this to nil which
      #   will not use a thread pool to make slot supplier calls, but that is dangerous and not advised because even the
      #   slightest blocking call can slow down the system.
      def initialize(
        workflow_slot_supplier:,
        activity_slot_supplier:,
        local_activity_slot_supplier:,
        custom_slot_supplier_thread_pool: ThreadPool.default
      )
        @workflow_slot_supplier = workflow_slot_supplier
        @activity_slot_supplier = activity_slot_supplier
        @local_activity_slot_supplier = local_activity_slot_supplier
        @custom_slot_supplier_thread_pool = custom_slot_supplier_thread_pool
      end

      # @!visibility private
      def _to_bridge_options
        Internal::Bridge::Worker::TunerOptions.new(
          workflow_slot_supplier: workflow_slot_supplier._to_bridge_options(self),
          activity_slot_supplier: activity_slot_supplier._to_bridge_options(self),
          local_activity_slot_supplier: local_activity_slot_supplier._to_bridge_options(self)
        )
      end
    end
  end
end
