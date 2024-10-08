# frozen_string_literal: true

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
        end

        # A slot supplier that will dynamically adjust the number of slots based on resource usage.
        #
        # @note WARNING: This API is experimental.
        class ResourceBased < SlotSupplier
          attr_reader :tuner_options, :slot_options

          # Create a reosurce-based slot supplier.
          #
          # @param tuner_options [ResourceBasedTunerOptions] General tuner options.
          # @param slot_options [ResourceBasedSlotOptions] Slot-supplier-specific tuner options.
          def initialize(tuner_options:, slot_options:) # rubocop:disable Lint/MissingSuper
            @tuner_options = tuner_options
            @slot_options = slot_options
          end
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
      ResourceBasedTunerOptions = Struct.new(
        :target_memory_usage,
        :target_cpu_usage,
        keyword_init: true
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
      ResourceBasedSlotOptions = Struct.new(
        :min_slots,
        :max_slots,
        :ramp_throttle,
        keyword_init: true
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

      # Create a tuner from 3 slot suppliers.
      #
      # @param workflow_slot_supplier [SlotSupplier] Slot supplier for workflows.
      # @param activity_slot_supplier [SlotSupplier] Slot supplier for activities.
      # @param local_activity_slot_supplier [SlotSupplier] Slot supplier for local activities.
      def initialize(
        workflow_slot_supplier:,
        activity_slot_supplier:,
        local_activity_slot_supplier:
      )
        @workflow_slot_supplier = workflow_slot_supplier
        @activity_slot_supplier = activity_slot_supplier
        @local_activity_slot_supplier = local_activity_slot_supplier
      end
    end
  end
end
