# frozen_string_literal: true

require 'pathname'
require 'temporalio/cancellation'
require 'temporalio/client'
require 'temporalio/env_config'
require 'temporalio/simple_plugin'
require 'temporalio/worker'
require 'temporalio/worker/deployment_options'
require 'temporalio/worker_deployment_version'

module Temporalio
  module Contrib
    module Aws
      # Runs a fresh Temporal worker for each AWS Lambda invocation.
      #
      # WARNING: AWS Lambda support is experimental.
      #
      # The event is ignored: Temporal tasks are polled until the invocation's shutdown budget begins.
      # Shutdown is cooperative. Activities must respond to cancellation, and hooks must respect their remaining budget.
      #
      # {define} creates a handler without running a worker. Each call to the returned Proc runs a new worker until
      # its shutdown budget begins, then waits for shutdown and cleanup before returning.
      #
      # @example Lambda entrypoint configured as lambda_function.lambda_handler
      #   require 'temporalio/contrib/aws/lambda_worker'
      #   require_relative 'my_workflow'
      #
      #   WORKER_HANDLER = Temporalio::Contrib::Aws::LambdaWorker.define(
      #     Temporalio::WorkerDeploymentVersion.new(
      #       deployment_name: ENV.fetch('TEMPORAL_DEPLOYMENT_NAME'),
      #       build_id: ENV.fetch('TEMPORAL_WORKER_BUILD_ID')
      #     ),
      #     options: Temporalio::Contrib::Aws::LambdaWorker::Options.new(
      #       task_queue: 'my-task-queue', workflows: [MyWorkflow]
      #     )
      #   )
      #
      #   def lambda_handler(event:, context:)
      #     WORKER_HANDLER.call(event:, context:)
      #   end
      class LambdaWorker
        Options = Data.define(
          :task_queue, :activities, :workflows, :client_options, :worker_options,
          :default_versioning_behavior, :shutdown_buffer, :shutdown_hooks, :plugins
        )

        # Immutable handler configuration. SDK objects in the collections are shared, not cloned.
        class Options
          # Create options for a Lambda worker.
          #
          # @param task_queue [String, nil] Task queue, defaulting to `TEMPORAL_TASK_QUEUE`.
          # @param activities [Array] Activity registrations.
          # @param workflows [Array] Workflow registrations.
          # @param client_options [Hash] Client.connect overrides, including `target_host` and `namespace`.
          # @param worker_options [Hash] Worker constructor overrides for Lambda-tuned defaults. The adapter controls
          #   deployment settings and invocation identity, and always disables eager activity execution.
          # @param default_versioning_behavior [VersioningBehavior] Default for workflows without an explicit behavior.
          # @param shutdown_buffer [Numeric] Seconds reserved before the Lambda deadline for shutdown and hooks.
          # @param shutdown_hooks [Array<Proc>] Hooks receiving remaining seconds after worker and connection cleanup.
          #   Failures are logged and do not prevent subsequent hooks.
          # @param plugins [Array<Client::Plugin, Worker::Plugin>] Invocation plugins.
          #   WARNING: Plugins are experimental.
          #
          # @example Compose existing tracing support with application-managed flushing
          #   require 'temporalio/contrib/open_telemetry'
          #
          #   tracing = Temporalio::SimplePlugin.new(
          #     name: 'application-tracing',
          #     client_interceptors: [
          #       Temporalio::Contrib::OpenTelemetry::TracingInterceptor.new(provider.tracer('temporal-ruby'))
          #     ]
          #   )
          #   options = Temporalio::Contrib::Aws::LambdaWorker::Options.new(
          #     plugins: [tracing],
          #     shutdown_hooks: [
          #       ->(remaining) { provider.force_flush(timeout: remaining) if remaining.positive? }
          #     ]
          #   )
          def initialize(
            task_queue: nil, activities: [], workflows: [], client_options: {}, worker_options: {},
            default_versioning_behavior: VersioningBehavior::PINNED, shutdown_buffer: 7,
            shutdown_hooks: [], plugins: []
          )
            unless shutdown_buffer.is_a?(Numeric) && shutdown_buffer.finite? && shutdown_buffer >= 0
              raise ArgumentError, 'shutdown_buffer must be finite and non-negative'
            end
            unless [VersioningBehavior::UNSPECIFIED, VersioningBehavior::PINNED,
                    VersioningBehavior::AUTO_UPGRADE].include?(default_versioning_behavior)
              raise ArgumentError, 'Invalid default_versioning_behavior'
            end

            [activities, workflows, shutdown_hooks, plugins].each do |value|
              raise TypeError, 'registrations, shutdown_hooks, and plugins must be arrays' unless value.is_a?(Array)
            end
            unless client_options.is_a?(Hash) && worker_options.is_a?(Hash)
              raise TypeError, 'client_options and worker_options must be hashes'
            end
            unless shutdown_hooks.all? { |hook| hook.respond_to?(:call) }
              raise ArgumentError, 'shutdown_hooks must be callable'
            end

            # Steep cannot see the keyword constructor synthesized by Data.define.
            # steep:ignore:start
            super(
              task_queue: LambdaWorker._immutable_copy(task_queue),
              activities: LambdaWorker._immutable_copy(activities),
              workflows: LambdaWorker._immutable_copy(workflows),
              client_options: LambdaWorker._immutable_copy(client_options),
              worker_options: LambdaWorker._immutable_copy(worker_options),
              default_versioning_behavior:, shutdown_buffer:,
              shutdown_hooks: LambdaWorker._immutable_copy(shutdown_hooks),
              plugins: LambdaWorker._immutable_copy(plugins)
            )
            # steep:ignore:end
          end

          # Return new options without sharing mutable collections with the caller.
          def with(**kwargs)
            self.class.new(**to_h, **kwargs)
          end
        end

        # @!visibility private
        class EnforcementPlugin < SimplePlugin
          def initialize(version, behavior, identity, cancellation)
            super(name: 'temporalio-aws-lambda-enforcement')
            @deployment = Worker::DeploymentOptions.new(
              version:, use_worker_versioning: true, default_versioning_behavior: behavior
            ).freeze
            @identity = identity
            @cancellation = cancellation
          end

          # @!visibility private
          def configure_worker(options)
            options.with(deployment_options: @deployment, identity: @identity, disable_eager_activity_execution: true)
          end

          # @!visibility private
          def run_worker(options, next_call)
            next_call.call(options.with(cancellation: @cancellation, shutdown_signals: []))
          end

          # @!visibility private
          def connect_client(options, next_call)
            next_call.call(options.with(identity: @identity))
          end
        end
        private_constant :EnforcementPlugin

        class << self
          # Define a reusable Lambda handler.
          #
          # Each invocation resolves environment/TOML configuration, connects a client, and runs a new worker.
          # Deployment versioning is always enabled. PINNED executions require retaining their deployed Lambda version
          # until completion or migration; AUTO_UPGRADE instead requires replay-compatible workflow changes.
          #
          # @param version [WorkerDeploymentVersion] Required deployment name and build ID.
          # @param options [Options] Initial invocation configuration.
          # @yield [options, context] Optional per-invocation configuration, returning new Options.
          # @yieldparam options [Options] Initial configuration.
          # @yieldparam context [Object] AWS Lambda Ruby context.
          # @yieldreturn [Options] Configuration for this invocation.
          # @return [Proc] Handler accepting positional `(event, context)` or Ruby Lambda's `event:, context:` keywords.
          def define(version, options: Options.new, &configure)
            _define(version, options:, dependencies: _default_dependencies, &configure)
          end

          # @!visibility private
          def _define(version, options:, dependencies:, &configure)
            unless version.is_a?(WorkerDeploymentVersion) &&
                   version.deployment_name.is_a?(String) && !version.deployment_name.strip.empty? &&
                   version.build_id.is_a?(String) && !version.build_id.strip.empty?
              raise ArgumentError, 'version must have a non-empty deployment_name and build_id'
            end
            raise TypeError, 'options must be LambdaWorker::Options' unless options.is_a?(Options)

            version = WorkerDeploymentVersion.new(
              deployment_name: version.deployment_name.dup.freeze, build_id: version.build_id.dup.freeze
            ).freeze
            invocation_mutex = Mutex.new
            lambda do |*args, **kwargs|
              context = kwargs.key?(:context) ? kwargs.fetch(:context) : args.fetch(1)
              raise 'Lambda handler is already running an invocation' unless invocation_mutex.try_lock

              begin
                _invoke(version, options, context, dependencies:, &configure)
              ensure
                invocation_mutex.unlock
              end
            end
          end

          # @!visibility private
          def _immutable_copy(value)
            case value
            when Hash
              value.to_h { |key, item| [_immutable_copy(key), _immutable_copy(item)] }.freeze
            when Array
              value.map { |item| _immutable_copy(item) }.freeze
            when String
              value.dup.freeze
            else
              value
            end
          end

          private

          def _invoke(version, options, context, dependencies:)
            remaining = Float(context.get_remaining_time_in_millis) or raise TypeError, 'Invalid remaining time'
            remaining /= 1000
            unless remaining.finite? && remaining.positive?
              raise ArgumentError, 'Lambda remaining time must be finite and positive'
            end

            clock = dependencies.fetch(:clock)
            deadline = clock.call + remaining
            identity = "#{context.aws_request_id}@#{context.invoked_function_arn}"
            context_values = [context.aws_request_id, context.invoked_function_arn]
            if context_values.any? { |value| !value.is_a?(String) || value.empty? }
              raise ArgumentError, 'Lambda context must provide request ID and function ARN'
            end

            logger = options.client_options.fetch(:logger) { Logger.new($stdout, level: Logger::WARN) }
            hooks = options.shutdown_hooks
            # @type var client: Client?
            client = nil
            # @type var worker: Worker?
            worker = nil
            # @type var timer: Thread?
            timer = nil
            begin
              options = yield(options, context) if block_given?
              raise TypeError, 'configure must return LambdaWorker::Options' unless options.is_a?(Options)

              logger = options.client_options.fetch(:logger, logger)
              hooks = options.shutdown_hooks
              task_queue = options.task_queue || dependencies.fetch(:getenv).call('TEMPORAL_TASK_QUEUE')
              unless task_queue.is_a?(String) && !task_queue.strip.empty?
                raise ArgumentError, 'task_queue must be set or TEMPORAL_TASK_QUEUE must be present'
              end

              client_args, client_options = _client_options(options, dependencies:)
              worker_options = _worker_options(options)
              client_plugins, worker_plugins = _plugins(
                options.plugins + client_options.fetch(:plugins, []) + worker_options.fetch(:plugins, [])
              )
              cancellation, cancel = Cancellation.new
              enforcement = EnforcementPlugin.new(version, options.default_versioning_behavior, identity, cancellation)
              work_time = deadline - clock.call - options.shutdown_buffer
              raise 'Lambda timeout leaves too little time for work' unless work_time.positive?

              logger.warn("Lambda worker has only #{work_time.round(3)} seconds for work") if work_time < 5
              timer = dependencies.fetch(:start_shutdown_timer).call(work_time, &cancel)
              client = dependencies.fetch(:connect_client).call(
                *client_args, **client_options, identity:, plugins: client_plugins + [enforcement]
              )
              return if cancellation.canceled?

              # Client plugins propagate first, but worker-local plugins run later; enforcement must remain last.
              worker = dependencies.fetch(:create_worker).call(
                **worker_options,
                client:, task_queue:, activities: options.activities, workflows: options.workflows,
                plugins: worker_plugins + [enforcement]
              )
              raise 'Worker factory returned no worker' unless worker

              worker.run(cancellation:, shutdown_signals: [])
              nil
            ensure
              _cleanup(logger, 'worker cleanup') { worker&._close }
              _cleanup(logger, 'client cleanup') { client&.connection&._close }
              if timer
                timer.kill
                timer.join
              end
              hooks.each do |hook|
                _cleanup(logger, 'shutdown hook') { hook.call([deadline - clock.call, 0.0].max) }
              end
            end
          end

          def _plugins(plugins)
            client_plugins = []
            worker_plugins = []
            plugins.each do |plugin|
              if plugin.is_a?(Client::Plugin)
                Client._validate_plugins!([plugin])
                Worker._validate_plugins!([plugin]) if plugin.is_a?(Worker::Plugin)
                client_plugins << plugin
              elsif plugin.is_a?(Worker::Plugin)
                Worker._validate_plugins!([plugin])
                worker_plugins << plugin
              else
                raise ArgumentError, "#{plugin.class} does not implement a client or worker plugin"
              end
            end
            [client_plugins, worker_plugins]
          end

          def _client_options(options, dependencies:)
            getenv = dependencies.fetch(:getenv)
            path = getenv.call('TEMPORAL_CONFIG_FILE')
            if path.nil? || path.empty?
              root = getenv.call('LAMBDA_TASK_ROOT')
              path = File.join(root.nil? || root.empty? ? Dir.pwd : root, 'temporal.toml')
              path = nil unless File.file?(path)
            end
            args, loaded = dependencies.fetch(:load_client_options).call(path)
            overrides = options.client_options.dup
            target_host = overrides.delete(:target_host) || args[0]
            namespace = overrides.delete(:namespace) || args[1]
            unless target_host.is_a?(String) && !target_host.empty? && namespace.is_a?(String) && !namespace.empty?
              raise ArgumentError, 'Temporal target_host and namespace must be configured'
            end

            [[target_host, namespace], loaded.merge(overrides)]
          end

          def _worker_options(options)
            {
              tuner: Worker::Tuner.create_fixed(workflow_slots: 10, activity_slots: 2, local_activity_slots: 2),
              max_cached_workflows: 30,
              max_concurrent_workflow_task_polls: 2,
              max_concurrent_activity_task_polls: 1,
              graceful_shutdown_period: 5
            }.merge(options.worker_options)
          end

          def _cleanup(logger, description)
            yield
          rescue StandardError => e
            begin
              logger.error("Lambda worker #{description} failed: #{e}")
            rescue StandardError
              nil
            end
          end

          def _default_dependencies
            {
              clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) },
              getenv: ->(name) { ENV.fetch(name, nil) },
              load_client_options: lambda do |path|
                if path
                  EnvConfig::ClientConfig.load_client_connect_options(config_source: Pathname.new(path))
                else
                  EnvConfig::ClientConfig.load_client_connect_options(disable_file: true)
                end
              end,
              connect_client: Client.method(:connect),
              create_worker: Worker.method(:new),
              start_shutdown_timer: lambda do |delay, &cancel|
                Thread.new do
                  sleep(delay)
                  cancel.call
                end
              end
            }.freeze
          end
        end
      end
    end
  end
end
