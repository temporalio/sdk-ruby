# frozen_string_literal: true

require 'temporalio/activity'
require 'temporalio/cancellation'
require 'temporalio/client'
require 'temporalio/error'
require 'temporalio/internal/bridge'
require 'temporalio/internal/bridge/worker'
require 'temporalio/internal/proto_utils'
require 'temporalio/internal/worker/activity_worker'
require 'temporalio/internal/worker/multi_runner'
require 'temporalio/internal/worker/workflow_instance'
require 'temporalio/internal/worker/workflow_worker'
require 'temporalio/worker/activity_executor'
require 'temporalio/worker/illegal_workflow_call_validator'
require 'temporalio/worker/interceptor'
require 'temporalio/worker/poller_behavior'
require 'temporalio/worker/thread_pool'
require 'temporalio/worker/tuner'
require 'temporalio/worker/workflow_executor'

module Temporalio
  # Worker for processing activities and workflows on a task queue.
  #
  # Workers are created for a task queue and the items they can run. Then {run} is used for running a single worker, or
  # {run_all} is used for a collection of workers. These can wait until a block is complete or a {Cancellation} is
  # canceled.
  class Worker
    Options = Data.define(
      :client,
      :task_queue,
      :activities,
      :workflows,
      :tuner,
      :activity_executors,
      :workflow_executor,
      :interceptors,
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
      :disable_eager_activity_execution,
      :illegal_workflow_calls,
      :workflow_failure_exception_types,
      :workflow_payload_codec_thread_pool,
      :unsafe_workflow_io_enabled,
      :deployment_options,
      :workflow_task_poller_behavior,
      :activity_task_poller_behavior,
      :debug_mode
    )

    # Options as returned from {options} for `**to_h` splat use in {initialize}. See {initialize} for details.
    #
    # Note, the `client` within can be replaced via client setter.
    class Options; end # rubocop:disable Lint/EmptyClass

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
      require 'digest'

      saw_bridge = false
      build_id = $LOADED_FEATURES.each_with_object(Digest::MD5.new) do |file, digest|
        saw_bridge = true if file.include?('temporalio_bridge.')
        digest.update(File.read(file)) if File.file?(file)
      end.hexdigest
      raise 'Temporal bridge library not in $LOADED_FEATURES, unable to calculate default build ID' unless saw_bridge

      build_id
    end

    # @return [DeploymentOptions] Default deployment options, which does not use worker versioning
    #   or a deployment name, and sets the build id to the one from {self.default_build_id}.
    def self.default_deployment_options
      @default_deployment_options ||= DeploymentOptions.new(
        version: WorkerDeploymentVersion.new(deployment_name: '', build_id: Worker.default_build_id)
      )
    end

    # Run all workers until cancellation or optional block completes. When the cancellation or block is complete, the
    # workers are shut down. This will return the block result if everything successful or raise an error if not. See
    # {run} for details on how worker shutdown works.
    #
    # @param workers [Array<Worker>] Workers to run.
    # @param cancellation [Cancellation] Cancellation that can be canceled to shut down all workers.
    # @param shutdown_signals [Array] Signals to trap and cause worker shutdown.
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
      shutdown_signals: [],
      raise_in_block_on_shutdown: Error::CanceledError.new('Workers finished'),
      wait_block_complete: true,
      &block
    )
      # Confirm there is at least one and they are all workers
      raise ArgumentError, 'At least one worker required' if workers.empty?
      raise ArgumentError, 'Not all parameters are workers' unless workers.all? { |w| w.is_a?(Worker) }

      Internal::Bridge.assert_fiber_compatibility!

      # Start the multi runner
      runner = Internal::Worker::MultiRunner.new(workers:, shutdown_signals:)

      # Apply block
      runner.apply_thread_or_fiber_block(&block)

      # Reuse first worker logger
      logger = workers.first&.options&.logger or raise # Never nil

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
        # TODO(cretz): Consider improving performance instead of this case statement
        case event
        when Internal::Worker::MultiRunner::Event::PollSuccess
          # Successful poll
          event.worker #: Worker
               ._on_poll_bytes(runner, event.worker_type, event.bytes)
        when Internal::Worker::MultiRunner::Event::PollFailure
          # Poll failure, this causes shutdown of all workers
          logger.error('Poll failure (beginning worker shutdown if not already occurring)')
          logger.error(event.error)
          first_error ||= event.error
          runner.initiate_shutdown
        when Internal::Worker::MultiRunner::Event::WorkflowActivationDecoded
          # Came back from a codec as decoded
          event.workflow_worker.handle_activation(runner:, activation: event.activation, decoded: true)
        when Internal::Worker::MultiRunner::Event::WorkflowActivationComplete
          # An activation is complete
          event.workflow_worker.handle_activation_complete(
            runner:,
            activation_completion: event.activation_completion,
            encoded: event.encoded,
            completion_complete_queue: event.completion_complete_queue
          )
        when Internal::Worker::MultiRunner::Event::WorkflowActivationCompletionComplete
          # Completion complete, only need to log error if it occurs here
          if event.error
            logger.error("Activation completion failed to record on run ID #{event.run_id}")
            logger.error(event.error)
          end
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
        when Internal::Worker::MultiRunner::Event::ShutdownSignalReceived
          logger.info('Signal received, beginning worker shutdown')
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
          when Internal::Worker::MultiRunner::Event::ShutdownSignalReceived
            # Do nothing, waiting for block
          else
            raise "Unexpected event: #{event}"
          end
        end
      end

      # Notify each worker we're done with it
      workers.each(&:_on_shutdown_complete)

      # If there was an shutdown-causing error, we raise that
      if !first_error.nil?
        raise first_error
      elsif block_result.is_a?(Internal::Worker::MultiRunner::Event::BlockSuccess)
        block_result.result
      end
    end

    # @return [Hash<String, [:all, Array<Symbol, IllegalWorkflowCallValidator>, IllegalWorkflowCallValidator]>] Default,
    #   immutable set illegal calls used for the `illegal_workflow_calls` worker option. See the documentation of that
    #   option for more details.
    def self.default_illegal_workflow_calls
      @default_illegal_workflow_calls ||= begin
        hash = {
          'BasicSocket' => :all,
          'Date' => %i[initialize today],
          'DateTime' => %i[initialize now],
          'Dir' => :all,
          'Fiber' => [:set_scheduler],
          'File' => :all,
          'FileTest' => :all,
          'FileUtils' => :all,
          'Find' => :all,
          'GC' => :all,
          'IO' => [
            :read
            # Intentionally leaving out write so puts will work. We don't want to add heavy logic replacing stdout or
            # trying to derive whether it's file vs stdout write.
            #:write
          ],
          'Kernel' => %i[abort at_exit autoload autoload? eval exec exit fork gets load open rand readline readlines
                         spawn srand system test trap],
          'Net::HTTP' => :all,
          'Pathname' => :all,
          # TODO(cretz): Investigate why clock_gettime called from Timeout thread affects this code at all. Stack trace
          # test executing activities inside a timeout will fail if clock_gettime is blocked.
          'Process' => %i[abort argv0 daemon detach exec exit exit! fork kill setpriority setproctitle setrlimit setsid
                          spawn times wait wait2 waitall warmup],
          # TODO(cretz): Allow Ractor.current since exception formatting in error_highlight references it
          # 'Ractor' => :all,
          'Random::Base' => [:initialize],
          'Resolv' => :all,
          'SecureRandom' => :all,
          'Signal' => :all,
          'Socket' => :all,
          'Tempfile' => :all,
          'Thread' => %i[abort_on_exception= exit fork handle_interrupt ignore_deadlock= kill new pass
                         pending_interrupt? report_on_exception= start stop initialize join name= priority= raise run
                         terminate thread_variable_set wakeup],
          'Time' => IllegalWorkflowCallValidator.default_time_validators
        } #: Hash[String, :all | Array[Symbol]]
        hash.each_value(&:freeze)
        hash.freeze
      end
    end

    # @return [Options] Options for this worker which has the same attributes as {initialize}.
    attr_reader :options

    # Create a new worker. At least one activity or workflow must be present.
    #
    # @param client [Client] Client for this worker.
    # @param task_queue [String] Task queue for this worker.
    # @param activities [Array<Activity::Definition, Class<Activity::Definition>, Activity::Definition::Info>]
    #   Activities for this worker.
    # @param workflows [Array<Class<Workflow::Definition>>] Workflows for this worker.
    # @param tuner [Tuner] Tuner that controls the amount of concurrent activities/workflows that run at a time.
    # @param activity_executors [Hash<Symbol, Worker::ActivityExecutor>] Executors that activities can run within.
    # @param workflow_executor [WorkflowExecutor] Workflow executor that workflow tasks run within. This must be a
    #   {WorkflowExecutor::ThreadPool} currently.
    # @param interceptors [Array<Interceptor::Activity, Interceptor::Workflow>] Interceptors specific to this worker.
    #   Note, interceptors set on the client that include the {Interceptor::Activity} or {Interceptor::Workflow} module
    #   are automatically included here, so no need to specify them again.
    # @param identity [String, nil] Override the identity for this worker. If unset, client identity is used.
    # @param logger [Logger] Logger to override client logger with. Default is the client logger.
    # @param max_cached_workflows [Integer] Number of workflows held in cache for use by sticky task queue. If set to 0,
    #   workflow caching and sticky queuing are disabled.
    # @param max_concurrent_workflow_task_polls [Integer] Maximum number of concurrent poll workflow task requests we
    #   will perform at a time on this worker's task queue.
    # @param nonsticky_to_sticky_poll_ratio [Float] `max_concurrent_workflow_task_polls` * this number = the number of
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
    # @param disable_eager_activity_execution [Boolean] If true, disables eager activity execution. Eager activity
    #   execution is an optimization on some servers that sends activities back to the same worker as the calling
    #   workflow if they can run there. This should be set to true for `max_task_queue_activities_per_second` to work
    #   and in a future version of this API may be implied as such (i.e. this setting will be ignored if that setting is
    #   set).
    # @param illegal_workflow_calls [Hash<String,
    #   [:all, Array<Symbol, IllegalWorkflowCallValidator>, IllegalWorkflowCallValidator]>] Set of illegal workflow
    #   calls that are considered unsafe/non-deterministic and will raise if seen. The key of the hash is the fully
    #   qualified string class name (no leading `::`). The value can be `:all` which means any use of the class is
    #   illegal. The value can be an array of symbols/validators for methods on the class that cannot be used. The
    #   methods refer to either instance or class methods, there is no way to differentiate at this time. Symbol method
    #   names are the normal way to say the method cannot be used, validators are only for advanced situations. Finally,
    #   for advanced situations, the hash value can be a class-level validator that is not tied to a specific method.
    # @param workflow_failure_exception_types [Array<Class<Exception>>] Workflow failure exception types. This is the
    #   set of exception types that, if a workflow-thrown exception extends, will cause the workflow/update to fail
    #   instead of suspending the workflow via task failure. These are applied in addition to the
    #   `workflow_failure_exception_type` on the workflow definition class itself. If {::Exception} is set, it
    #   effectively will fail a workflow/update in all user exception cases.
    # @param workflow_payload_codec_thread_pool [ThreadPool, nil] Thread pool to run payload codec encode/decode within.
    #   This is required if a payload codec exists and the worker is not fiber based. Codecs can potentially block
    #   execution which is why they need to be run in the background.
    # @param unsafe_workflow_io_enabled [Boolean] If false, the default, workflow code that invokes io_wait on the fiber
    #   scheduler will fail. Instead of setting this to true, users are encouraged to use {Workflow::Unsafe.io_enabled}
    #   with a block for narrower enabling of IO.
    # @param deployment_options [DeploymentOptions, nil] Deployment options for the worker.
    #   WARNING: This is an experimental feature and may change in the future.
    # @param workflow_task_poller_behavior [PollerBehavior] Specify the behavior of workflow task
    #   polling. Defaults to a 5-poller maximum.
    # @param activity_task_poller_behavior [PollerBehavior] Specify the behavior of activity task
    #   polling. Defaults to a 5-poller maximum.
    # @param debug_mode [Boolean] If true, deadlock detection is disabled. Deadlock detection will fail workflow tasks
    #   if they block the thread for too long. This defaults to true if the `TEMPORAL_DEBUG` environment variable is
    #   `true` or `1`.
    def initialize(
      client:,
      task_queue:,
      activities: [],
      workflows: [],
      tuner: Tuner.create_fixed,
      activity_executors: ActivityExecutor.defaults,
      workflow_executor: WorkflowExecutor::ThreadPool.default,
      interceptors: [],
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
      disable_eager_activity_execution: false,
      illegal_workflow_calls: Worker.default_illegal_workflow_calls,
      workflow_failure_exception_types: [],
      workflow_payload_codec_thread_pool: nil,
      unsafe_workflow_io_enabled: false,
      deployment_options: Worker.default_deployment_options,
      workflow_task_poller_behavior: PollerBehavior::SimpleMaximum.new(max_concurrent_workflow_task_polls),
      activity_task_poller_behavior: PollerBehavior::SimpleMaximum.new(max_concurrent_activity_task_polls),
      debug_mode: %w[true 1].include?(ENV['TEMPORAL_DEBUG'].to_s.downcase)
    )
      raise ArgumentError, 'Must have at least one activity or workflow' if activities.empty? && workflows.empty?

      Internal::ProtoUtils.assert_non_reserved_name(task_queue)

      @options = Options.new(
        client:,
        task_queue:,
        activities:,
        workflows:,
        tuner:,
        activity_executors:,
        workflow_executor:,
        interceptors:,
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
        disable_eager_activity_execution:,
        illegal_workflow_calls:,
        workflow_failure_exception_types:,
        workflow_payload_codec_thread_pool:,
        unsafe_workflow_io_enabled:,
        deployment_options:,
        workflow_task_poller_behavior:,
        activity_task_poller_behavior:,
        debug_mode:
      ).freeze

      should_enforce_versioning_behavior =
        deployment_options.use_worker_versioning &&
        deployment_options.default_versioning_behavior == VersioningBehavior::UNSPECIFIED
      # Preload workflow definitions and some workflow settings for the bridge
      workflow_definitions = Internal::Worker::WorkflowWorker.workflow_definitions(
        workflows,
        should_enforce_versioning_behavior: should_enforce_versioning_behavior
      )
      nondeterminism_as_workflow_fail, nondeterminism_as_workflow_fail_for_types =
        Internal::Worker::WorkflowWorker.bridge_workflow_failure_exception_type_options(
          workflow_failure_exception_types:, workflow_definitions:
        )

      # Create the bridge worker
      @bridge_worker = Internal::Bridge::Worker.new(
        client.connection._core_client,
        Internal::Bridge::Worker::Options.new(
          activity: !activities.empty?,
          workflow: !workflows.empty?,
          namespace: client.namespace,
          task_queue:,
          tuner: tuner._to_bridge_options,
          identity_override: identity,
          max_cached_workflows:,
          workflow_task_poller_behavior: workflow_task_poller_behavior._to_bridge_options,
          nonsticky_to_sticky_poll_ratio:,
          activity_task_poller_behavior: activity_task_poller_behavior._to_bridge_options,
          # For shutdown to work properly, we must disable remote activities
          # ourselves if there are no activities
          no_remote_activities: no_remote_activities || activities.empty?,
          sticky_queue_schedule_to_start_timeout:,
          max_heartbeat_throttle_interval:,
          default_heartbeat_throttle_interval:,
          max_worker_activities_per_second: max_activities_per_second,
          max_task_queue_activities_per_second:,
          graceful_shutdown_period:,
          nondeterminism_as_workflow_fail:,
          nondeterminism_as_workflow_fail_for_types:,
          deployment_options: deployment_options._to_bridge_options
        )
      )

      # Collect interceptors from client and params
      @activity_interceptors = (client.options.interceptors + interceptors).select do |i|
        i.is_a?(Interceptor::Activity)
      end
      @workflow_interceptors = (client.options.interceptors + interceptors).select do |i|
        i.is_a?(Interceptor::Workflow)
      end

      # Cancellation for the whole worker
      @worker_shutdown_cancellation = Cancellation.new

      # Create workers
      unless activities.empty?
        @activity_worker = Internal::Worker::ActivityWorker.new(worker: self,
                                                                bridge_worker: @bridge_worker)
      end
      unless workflows.empty?
        @workflow_worker = Internal::Worker::WorkflowWorker.new(
          bridge_worker: @bridge_worker,
          namespace: client.namespace,
          task_queue:,
          workflow_definitions:,
          workflow_executor:,
          logger:,
          data_converter: client.data_converter,
          metric_meter: client.connection.options.runtime.metric_meter,
          workflow_interceptors: @workflow_interceptors,
          disable_eager_activity_execution:,
          illegal_workflow_calls:,
          workflow_failure_exception_types:,
          workflow_payload_codec_thread_pool:,
          unsafe_workflow_io_enabled:,
          debug_mode:,
          assert_valid_local_activity: ->(activity) { _assert_valid_local_activity(activity) }
        )
      end

      # Validate worker
      @bridge_worker.validate

      # Mutex needed for accessing and replacing a client
      @client_mutex = Mutex.new
    end

    # @return [String] Task queue set on the worker options.
    def task_queue
      @options.task_queue
    end

    # @return [Client] Client for this worker. This is the same as {Options.client} in {options}, but surrounded by a
    #   mutex to be safe for client replacement in {client=}.
    def client
      @client_mutex.synchronize { @options.client }
    end

    # Replace the worker's client. When this is called, the client is replaced on the internal worker which means any
    # new calls will be made on the new client (but existing calls will still complete on the previous one). This is
    # commonly used for providing a new client with updated authentication credentials.
    #
    # @param new_client [Client] New client to use for new calls.
    def client=(new_client)
      @client_mutex.synchronize do
        @bridge_worker.replace_client(new_client.connection._core_client)
        @options = @options.with(client: new_client)
        new_client
      end
    end

    # Run this worker until cancellation or optional block completes. When the cancellation or block is complete, the
    # worker is shut down. This will return the block result if everything successful or raise an error if not.
    #
    # Upon shutdown (either via cancellation, block completion, or worker fatal error), the worker immediately stops
    # accepting new work. Then, after an optional grace period, all activities are canceled. This call then waits for
    # every activity and workflow task to complete before returning.
    #
    # @param cancellation [Cancellation] Cancellation that can be canceled to shut down this worker.
    # @param shutdown_signals [Array] Signals to trap and cause worker shutdown.
    # @param raise_in_block_on_shutdown [Exception, nil] Exception to {::Thread.raise} or {::Fiber.raise} if a block is
    #   present and still running on shutdown. If nil, `raise` is not used.
    # @param wait_block_complete [Boolean] If block given and shutdown caused by something else (e.g. cancellation
    #   canceled), whether to wait on the block to complete before returning.
    # @yield Optional block. This will be run in a new background thread or fiber. Worker will shut down upon completion
    #   of this and, assuming no other failures, return/bubble success/exception of the block.
    # @return [Object] Return value of the block or nil of no block given.
    def run(
      cancellation: Cancellation.new,
      shutdown_signals: [],
      raise_in_block_on_shutdown: Error::CanceledError.new('Workers finished'),
      wait_block_complete: true,
      &block
    )
      Worker.run_all(self, cancellation:, shutdown_signals:, raise_in_block_on_shutdown:, wait_block_complete:, &block)
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
    def _activity_interceptors
      @activity_interceptors
    end

    # @!visibility private
    def _on_poll_bytes(runner, worker_type, bytes)
      case worker_type
      when :activity
        @activity_worker.handle_task(Internal::Bridge::Api::ActivityTask::ActivityTask.decode(bytes))
      when :workflow
        @workflow_worker.handle_activation(
          runner:,
          activation: Internal::Bridge::Api::WorkflowActivation::WorkflowActivation.decode(bytes),
          decoded: false
        )
      else
        raise "Unrecognized worker type #{worker_type}"
      end
    end

    # @!visibility private
    def _on_shutdown_complete
      @workflow_worker&.on_shutdown_complete
      @workflow_worker = nil
    end

    # @!visibility private
    def _assert_valid_local_activity(activity)
      unless @activity_worker.nil?
        @activity_worker.assert_valid_activity(activity)
        return
      end

      raise ArgumentError,
            "Activity #{activity} " \
            'is not registered on this worker, no available activities.'
    end
  end
end
