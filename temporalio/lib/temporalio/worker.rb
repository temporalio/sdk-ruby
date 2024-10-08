# frozen_string_literal: true

require 'temporalio/activity'
require 'temporalio/cancellation'
require 'temporalio/client'
require 'temporalio/error'
require 'temporalio/internal/bridge'
require 'temporalio/internal/bridge/worker'
require 'temporalio/internal/worker/activity_worker'
require 'temporalio/internal/worker/multi_runner'
require 'temporalio/worker/activity_executor'
require 'temporalio/worker/interceptor'
require 'temporalio/worker/tuner'

module Temporalio
  # Worker for processing activities and workflows on a task queue.
  #
  # Workers are created for a task queue and the items they can run. Then {run} is used for running a single worker, or
  # {run_all} is used for a collection of workers. These can wait until a block is complete or a {Cancellation} is
  # canceled.
  class Worker
    # Options as returned from {options} for `**to_h`` splat use in {initialize}. See {initialize} for details.
    Options = Struct.new(
      :client,
      :task_queue,
      :activities,
      :activity_executors,
      :tuner,
      :interceptors,
      :build_id,
      :identity,
      :logger,
      :max_cached_workflows,
      :max_concurrent_workflow_task_polls,
      :nonsticky_to_sticky_poll_ratio,
      :max_concurrent_activity_task_polls,
      :no_remote_activities,
      :sticky_queue_schedule_to_start_timeout,
      :max_heartbeat_throttle_interval,
      :default_heartbeat_throttle_interval,
      :max_activities_per_second,
      :max_task_queue_activities_per_second,
      :graceful_shutdown_period,
      :use_worker_versioning,
      keyword_init: true
    )

    # @return [String] Memoized default build ID. This default value is built as a checksum of all of the loaded Ruby
    #   source files in `$LOADED_FEATURES`. Users may prefer to set the build ID to a better representation of the
    #   source.
    def self.default_build_id
      @default_build_id ||= _load_default_build_id
    end

    # @!visibility private
    def self._load_default_build_id
      # The goal is to get a hash of runtime code, both Temporal's and the
      # user's. After all options were explored, we have decided to default to
      # hashing all bytecode of required files. This means later/dynamic require
      # won't be accounted for because this is memoized. It also means the
      # tiniest code change will affect this, which is what we want since this
      # is meant to be a "binary checksum". We have chosen to use MD5 for speed,
      # similarity with other SDKs, and because security is not a factor.
      # TODO(cretz): Ensure Temporal bridge library is imported or something is
      # off

      $LOADED_FEATURES.each_with_object(Digest::MD5.new) do |file, digest|
        digest.update(File.read(file)) if File.file?(file)
      end.hexdigest
    end

    # Run all workers until cancellation or optional block completes. When the cancellation or block is complete, the
    # workers are shut down. This will return the block result if everything successful or raise an error if not. See
    # {run} for details on how worker shutdown works.
    #
    # @param workers [Array<Worker>] Workers to run.
    # @param cancellation [Cancellation] Cancellation that can be canceled to shut down all workers.
    # @param raise_in_block_on_shutdown [Exception, nil] Exception to {::Thread.raise} or {::Fiber.raise} if a block is
    #   present and still running on shutdown. If nil, `raise` is not used.
    # @param wait_block_complete [Boolean] If block given and shutdown caused by something else (e.g. cancellation
    #   canceled), whether to wait on the block to complete before returning.
    # @yield Optional block. This will be run in a new background thread or fiber. Workers will shut down upon
    #   completion of this and, assuming no other failures, return/bubble success/exception of the block.
    # @return [Object] Return value of the block or nil of no block given.
    def self.run_all(
      *workers,
      cancellation: Cancellation.new,
      raise_in_block_on_shutdown: Error::CanceledError.new('Workers finished'),
      wait_block_complete: true,
      &block
    )
      # Confirm there is at least one and they are all workers
      raise ArgumentError, 'At least one worker required' if workers.empty?
      raise ArgumentError, 'Not all parameters are workers' unless workers.all? { |w| w.is_a?(Worker) }

      Internal::Bridge.assert_fiber_compatibility!

      # Start the multi runner
      runner = Internal::Worker::MultiRunner.new(workers:)

      # Apply block
      runner.apply_thread_or_fiber_block(&block)

      # Reuse first worker logger
      logger = workers.first&.options&.logger or raise # Help steep

      # On cancel, initiate shutdown
      cancellation.add_cancel_callback do
        logger.info('Cancel invoked, beginning worker shutdown')
        runner.initiate_shutdown
      end

      # Poller loop, run until all pollers shut down
      first_error = nil
      block_result = nil
      loop do
        event = runner.next_event
        case event
        when Internal::Worker::MultiRunner::Event::PollSuccess
          # Successful poll
          event.worker._on_poll_bytes(event.worker_type, event.bytes)
        when Internal::Worker::MultiRunner::Event::PollFailure
          # Poll failure, this causes shutdown of all workers
          logger.error('Poll failure (beginning worker shutdown if not alaredy occurring)')
          logger.error(event.error)
          first_error ||= event.error
          runner.initiate_shutdown
        when Internal::Worker::MultiRunner::Event::PollerShutDown
          # Individual poller shut down. Nothing to do here until we support
          # worker status or something.
        when Internal::Worker::MultiRunner::Event::AllPollersShutDown
          # This is where we break the loop, no more polling can happen
          break
        when Internal::Worker::MultiRunner::Event::BlockSuccess
          logger.info('Block completed, beginning worker shutdown')
          block_result = event
          runner.initiate_shutdown
        when Internal::Worker::MultiRunner::Event::BlockFailure
          logger.error('Block failure (beginning worker shutdown)')
          logger.error(event.error)
          block_result = event
          first_error ||= event.error
          runner.initiate_shutdown
        else
          raise "Unexpected event: #{event}"
        end
      end

      # Now that all pollers have stopped, let's wait for all to complete
      begin
        runner.wait_complete_and_finalize_shutdown
      rescue StandardError => e
        logger.warn('Failed waiting and finalizing')
        logger.warn(e)
      end

      # If there was a block but not a result yet, we want to raise if that is
      # wanted, and wait if that is wanted
      if block_given? && block_result.nil?
        runner.raise_in_thread_or_fiber_block(raise_in_block_on_shutdown) unless raise_in_block_on_shutdown.nil?
        if wait_block_complete
          event = runner.next_event
          case event
          when Internal::Worker::MultiRunner::Event::BlockSuccess
            logger.info('Block completed (after worker shutdown)')
            block_result = event
          when Internal::Worker::MultiRunner::Event::BlockFailure
            logger.error('Block failure (after worker shutdown)')
            logger.error(event.error)
            block_result = event
            first_error ||= event.error
          else
            raise "Unexpected event: #{event}"
          end
        end
      end

      # If there was an shutdown-causing error, we raise that
      if !first_error.nil?
        raise first_error
      elsif block_result.is_a?(Internal::Worker::MultiRunner::Event::BlockSuccess)
        block_result.result
      end
    end

    # @return [Options] Frozen options for this client which has the same attributes as {initialize}.
    attr_reader :options

    # Create a new worker. At least one activity or workflow must be present.
    #
    # @param client [Client] Client for this worker.
    # @param task_queue [String] Task queue for this worker.
    # @param activities [Array<Activity, Class<Activity>, Activity::Definition>] Activities for this worker.
    # @param activity_executors [Hash<Symbol, Worker::ActivityExecutor>] Executors that activities can run within.
    # @param tuner [Tuner] Tuner that controls the amount of concurrent activities/workflows that run at a time.
    # @param interceptors [Array<Interceptor>] Interceptors specific to this worker. Note, interceptors set on the
    #   client that include the {Interceptor} module are automatically included here, so no need to specify them again.
    # @param build_id [String] Unique identifier for the current runtime. This is best set as a unique value
    #   representing all code and should change only when code does. This can be something like a git commit hash. If
    #   unset, default is hash of known Ruby code.
    # @param identity [String, nil] Override the identity for this worker. If unset, client identity is used.
    # @param max_cached_workflows [Integer] Number of workflows held in cache for use by sticky task queue. If set to 0,
    #   workflow caching and sticky queuing are disabled.
    # @param max_concurrent_workflow_task_polls [Integer] Maximum number of concurrent poll workflow task requests we
    #   will perform at a time on this worker's task queue.
    # @param nonsticky_to_sticky_poll_ratio [Float] `max_concurrent_workflow_task_polls`` * this number = the number of
    #   max pollers that will be allowed for the nonsticky queue when sticky tasks are enabled. If both defaults are
    #   used, the sticky queue will allow 4 max pollers while the nonsticky queue will allow one. The minimum for either
    #   poller is 1, so if `max_concurrent_workflow_task_polls` is 1 and sticky queues are enabled, there will be 2
    #   concurrent polls.
    # @param max_concurrent_activity_task_polls [Integer] Maximum number of concurrent poll activity task requests we
    #   will perform at a time on this worker's task queue.
    # @param no_remote_activities [Boolean] If true, this worker will only handle workflow tasks and local activities,
    #   it will not poll for activity tasks.
    # @param sticky_queue_schedule_to_start_timeout [Float] How long a workflow task is allowed to sit on the sticky
    #   queue before it is timed out and moved to the non-sticky queue where it may be picked up by any worker.
    # @param max_heartbeat_throttle_interval [Float] Longest interval for throttling activity heartbeats.
    # @param default_heartbeat_throttle_interval [Float] Default interval for throttling activity heartbeats in case
    #   per-activity heartbeat timeout is unset. Otherwise, it's the per-activity heartbeat timeout * 0.8.
    # @param max_activities_per_second [Float, nil] Limits the number of activities per second that this worker will
    #   process. The worker will not poll for new activities if by doing so it might receive and execute an activity
    #   which would cause it to exceed this limit.
    # @param max_task_queue_activities_per_second [Float, nil] Sets the maximum number of activities per second the task
    #   queue will dispatch, controlled server-side. Note that this only takes effect upon an activity poll request. If
    #   multiple workers on the same queue have different values set, they will thrash with the last poller winning.
    # @param graceful_shutdown_period [Float] Amount of time after shutdown is called that activities are given to
    #   complete before their tasks are canceled.
    # @param use_worker_versioning [Boolean] If true, the `build_id` argument must be specified, and this worker opts
    #   into the worker versioning feature. This ensures it only receives workflow tasks for workflows which it claims
    #   to be compatible with. For more information, see https://docs.temporal.io/workers#worker-versioning.
    def initialize(
      client:,
      task_queue:,
      activities: [],
      activity_executors: ActivityExecutor.defaults,
      tuner: Tuner.create_fixed,
      interceptors: [],
      build_id: Worker.default_build_id,
      identity: nil,
      logger: client.options.logger,
      max_cached_workflows: 1000,
      max_concurrent_workflow_task_polls: 5,
      nonsticky_to_sticky_poll_ratio: 0.2,
      max_concurrent_activity_task_polls: 5,
      no_remote_activities: false,
      sticky_queue_schedule_to_start_timeout: 10,
      max_heartbeat_throttle_interval: 60,
      default_heartbeat_throttle_interval: 30,
      max_activities_per_second: nil,
      max_task_queue_activities_per_second: nil,
      graceful_shutdown_period: 0,
      use_worker_versioning: false
    )
      # TODO(cretz): Remove when workflows come about
      raise ArgumentError, 'Must have at least one activity' if activities.empty?

      @options = Options.new(
        client:,
        task_queue:,
        activities:,
        activity_executors:,
        tuner:,
        interceptors:,
        build_id:,
        identity:,
        logger:,
        max_cached_workflows:,
        max_concurrent_workflow_task_polls:,
        nonsticky_to_sticky_poll_ratio:,
        max_concurrent_activity_task_polls:,
        no_remote_activities:,
        sticky_queue_schedule_to_start_timeout:,
        max_heartbeat_throttle_interval:,
        default_heartbeat_throttle_interval:,
        max_activities_per_second:,
        max_task_queue_activities_per_second:,
        graceful_shutdown_period:,
        use_worker_versioning:
      ).freeze

      # Create the bridge worker
      @bridge_worker = Internal::Bridge::Worker.new(
        client.connection._core_client,
        Internal::Bridge::Worker::Options.new(
          activity: !activities.empty?,
          workflow: false,
          namespace: client.namespace,
          task_queue:,
          tuner: Internal::Bridge::Worker::TunerOptions.new(
            workflow_slot_supplier: to_bridge_slot_supplier_options(tuner.workflow_slot_supplier),
            activity_slot_supplier: to_bridge_slot_supplier_options(tuner.activity_slot_supplier),
            local_activity_slot_supplier: to_bridge_slot_supplier_options(tuner.local_activity_slot_supplier)
          ),
          build_id:,
          identity_override: identity,
          max_cached_workflows:,
          max_concurrent_workflow_task_polls:,
          nonsticky_to_sticky_poll_ratio:,
          max_concurrent_activity_task_polls:,
          no_remote_activities:,
          sticky_queue_schedule_to_start_timeout:,
          max_heartbeat_throttle_interval:,
          default_heartbeat_throttle_interval:,
          max_worker_activities_per_second: max_activities_per_second,
          max_task_queue_activities_per_second:,
          graceful_shutdown_period:,
          use_worker_versioning:
        )
      )

      # Collect interceptors from client and params
      @all_interceptors = client.options.interceptors.select { |i| i.is_a?(Interceptor) } + interceptors

      # Cancellation for the whole worker
      @worker_shutdown_cancellation = Cancellation.new

      # Create workers
      # TODO(cretz): Make conditional when workflows appear
      @activity_worker = Internal::Worker::ActivityWorker.new(self, @bridge_worker)

      # Validate worker
      @bridge_worker.validate
    end

    # @return [String] Task queue set on the worker options.
    def task_queue
      @options.task_queue
    end

    # Run this worker until cancellation or optional block completes. When the cancellation or block is complete, the
    # worker is shut down. This will return the block result if everything successful or raise an error if not.
    #
    # Upon shutdown (either via cancellation, block completion, or worker fatal error), the worker immediately stops
    # accepting new work. Then, after an optional grace period, all activities are canceled. This call then waits for
    # every activity and workflow task to complete before returning.
    #
    # @param cancellation [Cancellation] Cancellation that can be canceled to shut down this worker.
    # @param raise_in_block_on_shutdown [Exception, nil] Exception to {::Thread.raise} or {::Fiber.raise} if a block is
    #   present and still running on shutdown. If nil, `raise` is not used.
    # @param wait_block_complete [Boolean] If block given and shutdown caused by something else (e.g. cancellation
    #   canceled), whether to wait on the block to complete before returning.
    # @yield Optional block. This will be run in a new background thread or fiber. Worker will shut down upon completion
    #   of this and, assuming no other failures, return/bubble success/exception of the block.
    # @return [Object] Return value of the block or nil of no block given.
    def run(
      cancellation: Cancellation.new,
      # TODO(cretz): Document that this can be set to nil
      raise_in_block_on_shutdown: Error::CanceledError.new('Workers finished'),
      wait_block_complete: true,
      &block
    )
      Worker.run_all(self, cancellation:, raise_in_block_on_shutdown:, wait_block_complete:, &block)
    end

    # @!visibility private
    def _worker_shutdown_cancellation
      @worker_shutdown_cancellation
    end

    # @!visibility private
    def _initiate_shutdown
      _bridge_worker.initiate_shutdown
      _, cancel_proc = _worker_shutdown_cancellation
      cancel_proc.call
    end

    # @!visibility private
    def _wait_all_complete
      @activity_worker&.wait_all_complete
    end

    # @!visibility private
    def _bridge_worker
      @bridge_worker
    end

    # @!visibility private
    def _all_interceptors
      @all_interceptors
    end

    # @!visibility private
    def _on_poll_bytes(worker_type, bytes)
      # TODO(cretz): Workflow workers
      raise "Unrecognized worker type #{worker_type}" unless worker_type == :activity

      @activity_worker.handle_task(Internal::Bridge::Api::ActivityTask::ActivityTask.decode(bytes))
    end

    private

    def to_bridge_slot_supplier_options(slot_supplier)
      if slot_supplier.is_a?(Tuner::SlotSupplier::Fixed)
        Internal::Bridge::Worker::TunerSlotSupplierOptions.new(
          fixed_size: slot_supplier.slots,
          resource_based: nil
        )
      elsif slot_supplier.is_a?(Tuner::SlotSupplier::ResourceBased)
        Internal::Bridge::Worker::TunerSlotSupplierOptions.new(
          fixed_size: nil,
          resource_based: Internal::Bridge::Worker::TunerResourceBasedSlotSupplierOptions.new(
            target_mem_usage: slot_supplier.tuner_options.target_memory_usage,
            target_cpu_usage: slot_supplier.tuner_options.target_cpu_usage,
            min_slots: slot_supplier.slot_options.min_slots,
            max_slots: slot_supplier.slot_options.max_slots,
            ramp_throttle: slot_supplier.slot_options.ramp_throttle
          )
        )
      else
        raise ArgumentError, 'Tuner slot suppliers must be instances of Fixed or ResourceBased'
      end
    end
  end
end
