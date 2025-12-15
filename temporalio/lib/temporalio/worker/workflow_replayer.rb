# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/converters'
require 'temporalio/internal/bridge'
require 'temporalio/internal/bridge/worker'
require 'temporalio/internal/worker/multi_runner'
require 'temporalio/internal/worker/workflow_worker'
require 'temporalio/worker/interceptor'
require 'temporalio/worker/plugin'
require 'temporalio/worker/poller_behavior'
require 'temporalio/worker/thread_pool'
require 'temporalio/worker/tuner'
require 'temporalio/worker/workflow_executor'
require 'temporalio/workflow'
require 'temporalio/workflow_history'

module Temporalio
  class Worker
    # Replayer to replay workflows from existing history.
    class WorkflowReplayer
      Options = Data.define(
        :workflows,
        :namespace,
        :task_queue,
        :data_converter,
        :workflow_executor,
        :plugins,
        :interceptors,
        :identity,
        :logger,
        :illegal_workflow_calls,
        :workflow_failure_exception_types,
        :workflow_payload_codec_thread_pool,
        :unsafe_workflow_io_enabled,
        :debug_mode,
        :runtime
      )

      # Options as returned from {options} representing the options passed to the constructor.
      class Options; end # rubocop:disable Lint/EmptyClass

      # @return [Options] Options for this replayer which has the same attributes as {initialize}.
      attr_reader :options

      # Create a new replayer. This combines some options from both {Worker.initialize} and {Client.initialize}.
      #
      # @param workflows [Array<Class<Workflow::Definition>>] Workflows for this replayer.
      # @param namespace [String] Namespace as set in the workflow info.
      # @param task_queue [String] Task queue as set in the workflow info.
      # @param data_converter [Converters::DataConverter] Data converter to use for all data conversions to/from
      #   payloads.
      # @param workflow_executor [WorkflowExecutor] Workflow executor that workflow tasks run within. This must be a
      #   {WorkflowExecutor::ThreadPool} currently.
      # @param plugins [Array<Plugin>] Plugins to use for configuring replayer and intercepting replay. WARNING: Plugins
      #   are experimental.
      # @param interceptors [Array<Interceptor::Workflow>] Workflow interceptors.
      # @param identity [String, nil] Override the identity for this replater.
      # @param logger [Logger] Logger to use. Defaults to stdout with warn level. Callers setting this logger are
      #   responsible for closing it.
      # @param illegal_workflow_calls [Hash<String, [:all, Array<Symbol>]>] Set of illegal workflow calls that are
      #   considered unsafe/non-deterministic and will raise if seen. The key of the hash is the fully qualified string
      #   class name (no leading `::`). The value is either `:all` which means any use of the class, or an array of
      #   symbols for methods on the class that cannot be used. The methods refer to either instance or class methods,
      #   there is no way to differentiate at this time.
      # @param workflow_failure_exception_types [Array<Class<Exception>>] Workflow failure exception types. This is the
      #   set of exception types that, if a workflow-thrown exception extends, will cause the workflow/update to fail
      #   instead of suspending the workflow via task failure. These are applied in addition to the
      #   `workflow_failure_exception_type` on the workflow definition class itself. If {::Exception} is set, it
      #   effectively will fail a workflow/update in all user exception cases.
      # @param workflow_payload_codec_thread_pool [ThreadPool, nil] Thread pool to run payload codec encode/decode
      #   within. This is required if a payload codec exists and the worker is not fiber based. Codecs can potentially
      #   block execution which is why they need to be run in the background.
      # @param unsafe_workflow_io_enabled [Boolean] If false, the default, workflow code that invokes io_wait on the
      #   fiber scheduler will fail. Instead of setting this to true, users are encouraged to use
      #   {Workflow::Unsafe.io_enabled} with a block for narrower enabling of IO.
      # @param debug_mode [Boolean] If true, deadlock detection is disabled. Deadlock detection will fail workflow tasks
      #   if they block the thread for too long. This defaults to true if the `TEMPORAL_DEBUG` environment variable is
      #   `true` or `1`.
      # @param runtime [Runtime] Runtime for this replayer.
      #
      # @yield If a block is present, this is the equivalent of calling {with_replay_worker} with the block and
      #   discarding the result.
      def initialize(
        workflows:,
        namespace: 'ReplayNamespace',
        task_queue: 'ReplayTaskQueue',
        data_converter: Converters::DataConverter.default,
        workflow_executor: WorkflowExecutor::ThreadPool.default,
        plugins: [],
        interceptors: [],
        identity: nil,
        logger: Logger.new($stdout, level: Logger::WARN),
        illegal_workflow_calls: Worker.default_illegal_workflow_calls,
        workflow_failure_exception_types: [],
        workflow_payload_codec_thread_pool: nil,
        unsafe_workflow_io_enabled: false,
        debug_mode: %w[true 1].include?(ENV['TEMPORAL_DEBUG'].to_s.downcase),
        runtime: Runtime.default,
        &
      )
        @options = Options.new(
          workflows:,
          namespace:,
          task_queue:,
          data_converter:,
          workflow_executor:,
          plugins:,
          interceptors:,
          identity:,
          logger:,
          illegal_workflow_calls:,
          workflow_failure_exception_types:,
          workflow_payload_codec_thread_pool:,
          unsafe_workflow_io_enabled:,
          debug_mode:,
          runtime:
        ).freeze
        # Apply plugins
        Worker._validate_plugins!(plugins)
        @options = plugins.reduce(@options) { |options, plugin| plugin.configure_workflow_replayer(options) }

        # Preload definitions and other settings
        @workflow_definitions = Internal::Worker::WorkflowWorker.workflow_definitions(
          @options.workflows, should_enforce_versioning_behavior: false
        )
        @nondeterminism_as_workflow_fail, @nondeterminism_as_workflow_fail_for_types =
          Internal::Worker::WorkflowWorker.bridge_workflow_failure_exception_type_options(
            workflow_failure_exception_types: @options.workflow_failure_exception_types,
            workflow_definitions: @workflow_definitions
          )
        # If there is a block, we'll go ahead and assume it's for with_replay_worker
        with_replay_worker(&) if block_given? # steep:ignore
      end

      # Replay a workflow history.
      #
      # If doing multiple histories, it is better to use {replay_workflows} or {with_replay_worker} since they create
      # a replay worker just once instead of each time like this call does.
      #
      # @param history [WorkflowHistory] History to replay.
      # @param raise_on_replay_failure [Boolean] If true, the default, this will raise an exception on any replay
      #   failure. If false and the replay fails, the failure will be available in {ReplayResult.replay_failure}.
      #
      # @return [ReplayResult] Result of the replay.
      def replay_workflow(history, raise_on_replay_failure: true)
        with_replay_worker { |worker| worker.replay_workflow(history, raise_on_replay_failure:) }
      end

      # Replay multiple workflow histories.
      #
      # @param histories [Enumerable<WorkflowHistory>] Histories to replay.
      # @param raise_on_replay_failure [Boolean] If true, this will raise an exception on any replay failure. If false,
      #   the default, and the replay fails, the failure will be available in {ReplayResult.replay_failure}.
      #
      # @return [Array<ReplayResult>] Results of the replay.
      def replay_workflows(histories, raise_on_replay_failure: false)
        with_replay_worker do |worker|
          histories.map { |h| worker.replay_workflow(h, raise_on_replay_failure:) }
        end
      end

      # Run a block of code with a {ReplayWorker} to execute replays.
      #
      # @yield Block of code to run with a replay worker.
      # @yieldparam [ReplayWorker] Worker to run replays on. Note, only one workflow can replay at a time.
      # @yieldreturn [Object] Result of the block.
      def with_replay_worker(&block)
        # Apply plugins
        run_block = proc do |options|
          # @type var options: Plugin::WithWorkflowReplayWorkerOptions
          block.call(options.worker)
        end
        run_block = options.plugins.reverse_each.reduce(run_block) do |next_call, plugin|
          proc do |options|
            plugin.with_workflow_replay_worker(options, next_call) # steep:ignore
          end
        end

        worker = ReplayWorker.new(
          options:,
          workflow_definitions: @workflow_definitions,
          nondeterminism_as_workflow_fail: @nondeterminism_as_workflow_fail,
          nondeterminism_as_workflow_fail_for_types: @nondeterminism_as_workflow_fail_for_types
        )
        begin
          run_block.call(Plugin::WithWorkflowReplayWorkerOptions.new(worker:))
        ensure
          worker._shutdown
        end
      end

      # Result of a single workflow replay run.
      class ReplayResult
        # @return [WorkflowHistory] History originally passed in to the replayer.
        attr_reader :history

        # @return [Exception, nil] Failure during replay if any.
        attr_reader :replay_failure

        # @!visibility private
        def initialize(history:, replay_failure:)
          @history = history
          @replay_failure = replay_failure
        end
      end

      # Replay worker that can be used to replay individual workflow runs. Only one call to {replay_workflow} can be
      # made at a time.
      class ReplayWorker
        # @!visibility private
        def initialize(
          options:,
          workflow_definitions:,
          nondeterminism_as_workflow_fail:,
          nondeterminism_as_workflow_fail_for_types:
        )
          # Create the bridge worker and the replayer
          @bridge_replayer, @bridge_worker = Internal::Bridge::Worker::WorkflowReplayer.new(
            options.runtime._core_runtime,
            Internal::Bridge::Worker::Options.new(
              namespace: options.namespace,
              task_queue: options.task_queue,
              tuner: Tuner.create_fixed(
                workflow_slots: 2, activity_slots: 1, local_activity_slots: 1
              )._to_bridge_options,
              identity_override: options.identity,
              max_cached_workflows: 2,
              workflow_task_poller_behavior:
                Temporalio::Worker::PollerBehavior::SimpleMaximum.new(2)._to_bridge_options,
              nonsticky_to_sticky_poll_ratio: 1.0,
              activity_task_poller_behavior:
                Temporalio::Worker::PollerBehavior::SimpleMaximum.new(1)._to_bridge_options,
              enable_workflows: true,
              enable_local_activities: false,
              enable_remote_activities: false,
              enable_nexus: false,
              sticky_queue_schedule_to_start_timeout: 1.0,
              max_heartbeat_throttle_interval: 1.0,
              default_heartbeat_throttle_interval: 1.0,
              max_worker_activities_per_second: nil,
              max_task_queue_activities_per_second: nil,
              graceful_shutdown_period: 0.0,
              nondeterminism_as_workflow_fail:,
              nondeterminism_as_workflow_fail_for_types:,
              deployment_options: Worker.default_deployment_options._to_bridge_options,
              plugins: options.plugins.map(&:name).uniq.sort
            )
          )

          # Create the workflow worker
          @workflow_worker = Internal::Worker::WorkflowWorker.new(
            bridge_worker: @bridge_worker,
            namespace: options.namespace,
            task_queue: options.task_queue,
            workflow_definitions:,
            workflow_executor: options.workflow_executor,
            logger: options.logger,
            data_converter: options.data_converter,
            metric_meter: options.runtime.metric_meter,
            workflow_interceptors: options.interceptors.select do |i|
              i.is_a?(Interceptor::Workflow)
            end,
            disable_eager_activity_execution: false,
            illegal_workflow_calls: options.illegal_workflow_calls,
            workflow_failure_exception_types: options.workflow_failure_exception_types,
            workflow_payload_codec_thread_pool: options.workflow_payload_codec_thread_pool,
            unsafe_workflow_io_enabled: options.unsafe_workflow_io_enabled,
            debug_mode: options.debug_mode,
            on_eviction: proc { |_, remove_job| @last_workflow_remove_job = remove_job }, # steep:ignore
            assert_valid_local_activity: ->(_) {}
          )

          # Create the runner
          @runner = Internal::Worker::MultiRunner.new(workers: [self], shutdown_signals: [])
        end

        # Replay a workflow history.
        #
        # @param history [WorkflowHistory] History to replay.
        # @param raise_on_replay_failure [Boolean] If true, the default, this will raise an exception on any replay
        #   failure. If false and the replay fails, the failure will be available in {ReplayResult.replay_failure}.
        #
        # @return [ReplayResult] Result of the replay.
        def replay_workflow(history, raise_on_replay_failure: true)
          raise ArgumentError, 'Expected history as WorkflowHistory' unless history.is_a?(WorkflowHistory)
          # Due to our event processing model, only one can run at a time
          raise 'Already running' if @running
          raise 'Replayer shutdown' if @shutdown

          # Push history proto
          # TODO(cretz): Unset this
          @running = true
          @last_workflow_remove_job = nil
          begin
            @bridge_replayer.push_history(
              history.workflow_id, Api::History::V1::History.new(events: history.events).to_proto
            )

            # Process events until workflow complete
            until @last_workflow_remove_job
              event = @runner.next_event
              case event
              when Internal::Worker::MultiRunner::Event::PollSuccess
                @workflow_worker.handle_activation(
                  runner: @runner,
                  activation: Internal::Bridge::Api::WorkflowActivation::WorkflowActivation.decode(event.bytes),
                  decoded: false
                )
              when Internal::Worker::MultiRunner::Event::WorkflowActivationDecoded
                @workflow_worker.handle_activation(runner: @runner, activation: event.activation, decoded: true)
              when Internal::Worker::MultiRunner::Event::WorkflowActivationComplete
                @workflow_worker.handle_activation_complete(
                  runner: @runner,
                  activation_completion: event.activation_completion,
                  encoded: event.encoded,
                  completion_complete_queue: event.completion_complete_queue
                )
              when Internal::Worker::MultiRunner::Event::WorkflowActivationCompletionComplete
              # Ignore
              else
                raise "Unexpected event: #{event}"
              end
            end

            # Create exception if removal is due to error
            err = if @last_workflow_remove_job.reason == :NONDETERMINISM
                    Workflow::NondeterminismError.new(
                      "#{@last_workflow_remove_job.reason}: #{@last_workflow_remove_job.message}"
                    )
                  elsif !%i[CACHE_FULL LANG_REQUESTED].include?(@last_workflow_remove_job.reason)
                    Workflow::InvalidWorkflowStateError.new(
                      "#{@last_workflow_remove_job.reason}: #{@last_workflow_remove_job.message}"
                    )
                  end
            # Raise if wanting to raise, otherwise return result
            raise err if raise_on_replay_failure && err

            ReplayResult.new(history:, replay_failure: err)
          ensure
            @running = false
          end
        end

        # @!visibility private
        def _shutdown
          @shutdown = true
          @runner.initiate_shutdown
          # Wait for all-pollers-shutdown before finalizing
          until @runner.next_event.is_a?(Internal::Worker::MultiRunner::Event::AllPollersShutDown); end
          @runner.wait_complete_and_finalize_shutdown
          @workflow_worker.on_shutdown_complete
          @workflow_worker = nil
        end

        # @!visibility private
        def _bridge_worker
          @bridge_worker
        end

        # @!visibility private
        def _initiate_shutdown
          _bridge_worker.initiate_shutdown
        end

        # @!visibility private
        def _wait_all_complete
          # Do nothing
        end
      end
    end
  end
end
