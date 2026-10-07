# frozen_string_literal: true

require 'logger'
require 'pathname'
require 'temporalio/cancellation'
require 'temporalio/client'
require 'temporalio/env_config'
require 'temporalio/worker'
require 'temporalio/worker/deployment_options'
require 'temporalio/worker/tuner'
require 'temporalio/worker_deployment_version'

module Temporalio
  module Contrib
    module Aws
      # Defines Temporal workers that run for a single AWS Lambda invocation.
      class LambdaWorker
        DEFAULT_ACTIVITY_SLOTS = 2
        DEFAULT_LOCAL_ACTIVITY_SLOTS = 2
        DEFAULT_WORKFLOW_SLOTS = 10
        DEFAULT_MAX_CACHED_WORKFLOWS = 30
        DEFAULT_GRACEFUL_SHUTDOWN_PERIOD = 5
        DEFAULT_SHUTDOWN_BUFFER = 7

        DEFAULT_WORKER_OPTIONS = {
          tuner: Worker::Tuner.create_fixed(
            workflow_slots: DEFAULT_WORKFLOW_SLOTS,
            activity_slots: DEFAULT_ACTIVITY_SLOTS,
            local_activity_slots: DEFAULT_LOCAL_ACTIVITY_SLOTS
          ),
          max_cached_workflows: DEFAULT_MAX_CACHED_WORKFLOWS,
          max_concurrent_workflow_task_polls: 2,
          max_concurrent_activity_task_polls: 1,
          graceful_shutdown_period: DEFAULT_GRACEFUL_SHUTDOWN_PERIOD,
          disable_eager_activity_execution: true
        }.freeze
        private_constant :DEFAULT_ACTIVITY_SLOTS
        private_constant :DEFAULT_LOCAL_ACTIVITY_SLOTS
        private_constant :DEFAULT_WORKFLOW_SLOTS
        private_constant :DEFAULT_MAX_CACHED_WORKFLOWS
        private_constant :DEFAULT_GRACEFUL_SHUTDOWN_PERIOD
        private_constant :DEFAULT_SHUTDOWN_BUFFER
        private_constant :DEFAULT_WORKER_OPTIONS

        Options = Data.define(
          :task_queue,
          :activities,
          :workflows,
          :client_options,
          :worker_options,
          :default_versioning_behavior,
          :shutdown_buffer,
          :shutdown_hooks,
          :plugins
        )

        # Immutable configuration used to define a Lambda handler.
        class Options
          # Create Lambda worker options.
          #
          # @param task_queue [String, nil] Task queue to poll. When nil, {LambdaWorker.define} uses
          #   `TEMPORAL_TASK_QUEUE`.
          # @param activities [Array] Activity registrations for each invocation's worker.
          # @param workflows [Array] Workflow registrations for each invocation's worker.
          # @param client_options [Hash] Overrides passed to {Client.connect}. `target_host` and `namespace` may be
          #   supplied here instead of via Temporal environment configuration.
          # @param client_connect_options [Hash, nil] Alias for `client_options`.
          # @param worker_options [Hash] Remaining options passed to the worker constructor. Values required by Lambda,
          #   including registrations, identity, and deployment options, are supplied by {LambdaWorker}.
          # @param shutdown_buffer [Numeric] Seconds reserved for graceful shutdown and hooks.
          # @param default_versioning_behavior [VersioningBehavior] Default behavior for workflows without an explicit
          #   versioning behavior. Defaults to pinned.
          # @param shutdown_hooks [Array<Proc>] No-argument hooks called after a worker has stopped.
          # @param plugins [Array<Client::Plugin, Worker::Plugin>] SDK plugins applied to each invocation.
          #   WARNING: Plugins are experimental.
          def initialize(
            task_queue: nil,
            activities: [],
            workflows: [],
            client_options: nil,
            client_connect_options: nil,
            worker_options: {},
            default_versioning_behavior: VersioningBehavior::PINNED,
            shutdown_buffer: DEFAULT_SHUTDOWN_BUFFER,
            shutdown_hooks: [],
            plugins: []
          )
            if !client_options.nil? && !client_connect_options.nil?
              raise ArgumentError, 'Only one of client_options and client_connect_options may be provided'
            end

            client_options ||= client_connect_options || {}
            raise TypeError, 'activities must be an Array' unless activities.is_a?(Array)
            raise TypeError, 'workflows must be an Array' unless workflows.is_a?(Array)
            raise TypeError, 'client_options must be a Hash' unless client_options.is_a?(Hash)
            raise TypeError, 'worker_options must be a Hash' unless worker_options.is_a?(Hash)
            raise TypeError, 'shutdown_hooks must be an Array' unless shutdown_hooks.is_a?(Array)
            raise TypeError, 'plugins must be an Array' unless plugins.is_a?(Array)
            raise TypeError, 'shutdown_buffer must be Numeric' unless shutdown_buffer.is_a?(Numeric)
            unless [VersioningBehavior::UNSPECIFIED, VersioningBehavior::PINNED,
                    VersioningBehavior::AUTO_UPGRADE].include?(default_versioning_behavior)
              raise ArgumentError, 'default_versioning_behavior must be a Temporalio::VersioningBehavior'
            end

            shutdown_buffer_seconds = Float(shutdown_buffer)
            unless shutdown_buffer_seconds&.finite? && shutdown_buffer_seconds >= 0
              raise ArgumentError, 'shutdown_buffer must be finite and non-negative'
            end

            lambda_worker_options = DEFAULT_WORKER_OPTIONS.merge(worker_options)
            unless worker_options.key?(:workflow_task_poller_behavior)
              lambda_worker_options[:workflow_task_poller_behavior] = Worker::PollerBehavior::SimpleMaximum.new(
                lambda_worker_options[:max_concurrent_workflow_task_polls]
              )
            end
            unless worker_options.key?(:activity_task_poller_behavior)
              lambda_worker_options[:activity_task_poller_behavior] = Worker::PollerBehavior::SimpleMaximum.new(
                lambda_worker_options[:max_concurrent_activity_task_polls]
              )
            end
            # Eager activities can outlive the invocation that accepted them, so Lambda workers must never enable them.
            lambda_worker_options[:disable_eager_activity_execution] = true

            # steep:ignore:start
            super(
              task_queue: LambdaWorker._immutable_copy(task_queue),
              activities: LambdaWorker._immutable_copy(activities),
              workflows: LambdaWorker._immutable_copy(workflows),
              client_options: LambdaWorker._immutable_copy(client_options),
              worker_options: LambdaWorker._immutable_copy(lambda_worker_options),
              default_versioning_behavior:,
              shutdown_buffer:,
              shutdown_hooks: LambdaWorker._immutable_copy(shutdown_hooks),
              plugins: LambdaWorker._immutable_copy(plugins)
            )
            # steep:ignore:end
            freeze
          end

          # Alias that makes it explicit these are arguments to {Client.connect}.
          #
          # @return [Hash] Immutable client connection overrides.
          def client_connect_options
            client_options
          end

          # Return a derived, immutable configuration.
          def with(**kwargs)
            if kwargs.key?(:client_connect_options)
              if kwargs.key?(:client_options)
                raise ArgumentError,
                      'Only one of client_options and client_connect_options may be provided'
              end

              kwargs[:client_options] = kwargs.delete(:client_connect_options)
            end
            self.class.new(**to_h, **kwargs)
          end
        end

        Definition = Data.define(
          :version,
          :options,
          :client_connect_args,
          :client_connect_options,
          :client_plugins,
          :worker_plugins,
          :deployment_options,
          :logger
        )
        private_constant :Definition

        # Restores the Lambda identity after client plugins transform connection options.
        # @!visibility private
        # rubocop:disable Style/DocumentationMethod
        class ConnectionIdentityPlugin
          include Client::Plugin

          def initialize(identity)
            @identity = identity
          end

          def name
            'temporalio-contrib-aws-lambda-worker-identity'
          end

          def configure_client(options)
            options
          end

          def connect_client(options, next_call)
            next_call.call(options.with(identity: @identity))
          end
        end

        # Restores values that must remain fixed for the invocation after worker plugins run.
        # @!visibility private
        class EnforcementPlugin
          include Worker::Plugin

          def initialize(deployment_options, identity)
            @deployment_options = deployment_options
            @identity = identity
          end

          def name
            'temporalio-contrib-aws-lambda-worker-enforcement'
          end

          def configure_worker(options)
            options.with(
              deployment_options: @deployment_options,
              identity: @identity,
              disable_eager_activity_execution: true
            )
          end

          def run_worker(options, next_call)
            next_call.call(options)
          end

          def configure_workflow_replayer(options)
            options
          end

          def with_workflow_replay_worker(options, next_call)
            next_call.call(options)
          end
        end
        # rubocop:enable Style/DocumentationMethod
        private_constant :ConnectionIdentityPlugin
        private_constant :EnforcementPlugin

        DEFAULT_LOGGER = Logger.new($stdout, level: Logger::WARN)
        private_constant :DEFAULT_LOGGER

        class << self
          # Define an AWS Lambda handler for one Temporal worker deployment version.
          #
          # Configuration is read and validated while defining the handler, so warm invocations cannot observe a
          # partially changed deployment configuration. Each handler call creates a new client and worker.
          #
          # @param version [WorkerDeploymentVersion] Required worker deployment name and build ID.
          # @param options [Options] Immutable Lambda worker configuration.
          # @return [Proc] Lambda handler accepting `(event, context)`.
          def define(version, options:)
            _define(version, options:, dependencies: _default_dependencies)
          end

          # @!visibility private
          def _define(version, options:, dependencies:)
            _validate_version!(version)
            version = WorkerDeploymentVersion.new(
              deployment_name: _immutable_copy(version.deployment_name),
              build_id: _immutable_copy(version.build_id)
            ).freeze
            unless options.is_a?(Options)
              raise TypeError,
                    'options must be a Temporalio::Contrib::Aws::LambdaWorker::Options'
            end

            selected_options = _materialize_options(options, dependencies:)
            client_connect_args, client_connect_options = _materialize_client_options(
              selected_options,
              dependencies:
            )
            client_plugins, worker_plugins = _partition_plugins(selected_options.plugins)
            Client._validate_plugins!(client_plugins)
            Worker._validate_plugins!(worker_plugins)
            client_plugins.each do |plugin|
              Worker._validate_plugins!([plugin]) if plugin.is_a?(Worker::Plugin)
            end

            deployment_options = Worker::DeploymentOptions.new(
              version:,
              use_worker_versioning: true,
              default_versioning_behavior: selected_options.default_versioning_behavior
            ).freeze

            definition = Definition.new(
              version:,
              options: selected_options,
              client_connect_args: _immutable_copy(client_connect_args),
              client_connect_options: _immutable_copy(client_connect_options),
              client_plugins: _immutable_copy(client_plugins),
              worker_plugins: _immutable_copy(worker_plugins),
              deployment_options:,
              logger: client_connect_options[:logger] || DEFAULT_LOGGER
            ).freeze

            lambda do |_event, context|
              _invoke(definition, context, dependencies:)
            end
          end

          # @!visibility private
          def _immutable_copy(value)
            case value
            when Hash
              value.each_with_object({}) do |(key, item), copy|
                copy[_immutable_copy(key)] = _immutable_copy(item)
              end.freeze
            when Array
              value.map { |item| _immutable_copy(item) }.freeze
            when String
              value.dup.freeze
            else
              value
            end
          end

          private

          def _materialize_options(options, dependencies:)
            task_queue = options.task_queue
            task_queue = dependencies.fetch(:getenv).call('TEMPORAL_TASK_QUEUE') if task_queue.nil?
            unless task_queue.is_a?(String) && !task_queue.empty?
              raise ArgumentError, 'task_queue must be set or TEMPORAL_TASK_QUEUE must be present'
            end

            hooks = options.shutdown_hooks + options.plugins.filter_map do |plugin|
              plugin.lambda_shutdown_hook if plugin.respond_to?(:lambda_shutdown_hook) # steep:ignore NoMethod
            end
            options.with(task_queue:, shutdown_hooks: hooks)
          end

          def _materialize_client_options(options, dependencies:)
            config_path = _config_path(dependencies:)
            client_connect_args, env_options = if dependencies[:load_client_options]
                                                 dependencies[:load_client_options].call(config_path)
                                               elsif config_path
                                                 EnvConfig::ClientConfig.load_client_connect_options(
                                                   config_source: Pathname.new(config_path)
                                                 )
                                               else
                                                 EnvConfig::ClientConfig.load_client_connect_options(disable_file: true)
                                               end
            overrides = options.client_options.dup
            target_host_override = overrides.delete(:target_host)
            address_override = overrides.delete(:address)
            target_host = target_host_override || address_override || client_connect_args[0]
            namespace = overrides.delete(:namespace) || client_connect_args[1]
            unless target_host.is_a?(String) && !target_host.empty?
              raise ArgumentError, 'Temporal target_host must be configured'
            end
            unless namespace.is_a?(String) && !namespace.empty?
              raise ArgumentError, 'Temporal namespace must be configured'
            end

            [[target_host, namespace], env_options.merge(overrides)]
          end

          def _config_path(dependencies:)
            config_file = dependencies.fetch(:getenv).call('TEMPORAL_CONFIG_FILE')
            return config_file unless config_file.nil? || config_file.empty?

            lambda_root = dependencies.fetch(:getenv).call('LAMBDA_TASK_ROOT')
            lambda_path = File.join(lambda_root, 'temporal.toml') unless lambda_root.nil? || lambda_root.empty?
            return lambda_path if lambda_path && dependencies.fetch(:readable_file).call(lambda_path)

            cwd_path = File.join(dependencies.fetch(:cwd).call, 'temporal.toml')
            return cwd_path if dependencies.fetch(:readable_file).call(cwd_path)

            nil
          end

          def _partition_plugins(plugins)
            client_plugins = []
            worker_plugins = []
            plugins.each do |plugin|
              if plugin.is_a?(Client::Plugin)
                client_plugins << plugin
              elsif plugin.is_a?(Worker::Plugin)
                worker_plugins << plugin
              else
                raise ArgumentError, "#{plugin.class} does not implement Temporalio::Client::Plugin or Temporalio::Worker::Plugin"
              end
            end
            [client_plugins, worker_plugins]
          end

          def _validate_version!(version)
            unless version.is_a?(WorkerDeploymentVersion) &&
                   version.deployment_name.is_a?(String) && !version.deployment_name.empty? &&
                   version.build_id.is_a?(String) && !version.build_id.empty?
              raise ArgumentError, 'version must have a deployment_name and build_id'
            end
          end

          def _invoke(definition, context, dependencies:)
            identity = _identity_from_context(context)
            work_time = _work_time(context, definition.options.shutdown_buffer, definition.logger)
            cancellation, cancel = Cancellation.new
            client = nil
            worker = nil
            shutdown_timer = nil
            begin
              shutdown_timer = dependencies.fetch(:start_shutdown_timer).call(work_time) { cancel.call }
              client_plugins = definition.client_plugins + [ConnectionIdentityPlugin.new(identity)]
              client = dependencies.fetch(:connect_client).call(
                *definition.client_connect_args,
                **definition.client_connect_options, identity:,
                                                     plugins: client_plugins
              )
              worker = dependencies.fetch(:create_worker).call(
                **definition.options.worker_options, client:,
                                                     task_queue: definition.options.task_queue,
                                                     activities: definition.options.activities,
                                                     workflows: definition.options.workflows,
                                                     identity:,
                                                     deployment_options: definition.deployment_options,
                                                     plugins: definition.worker_plugins + [
                                                       EnforcementPlugin.new(definition.deployment_options, identity)
                                                     ]
              )
              worker.run(cancellation:)
            ensure
              _cancel_shutdown_timer(shutdown_timer)
              _cleanup_worker(worker, dependencies:, logger: definition.logger)
              _run_shutdown_hooks(definition.options.shutdown_hooks, definition.logger)
              _cleanup_client(client, dependencies:, logger: definition.logger)
            end
          end

          def _identity_from_context(context)
            unless context.respond_to?(:aws_request_id) && context.respond_to?(:invoked_function_arn)
              raise ArgumentError, 'Lambda context must provide aws_request_id and invoked_function_arn'
            end

            request_id = context.aws_request_id
            function_arn = context.invoked_function_arn
            unless request_id.is_a?(String) && !request_id.empty? && function_arn.is_a?(String) && !function_arn.empty?
              raise ArgumentError, 'Lambda context aws_request_id and invoked_function_arn must be non-empty strings'
            end

            "#{request_id}@#{function_arn}"
          end

          def _work_time(context, shutdown_buffer, logger)
            unless context.respond_to?(:get_remaining_time_in_millis)
              raise ArgumentError, 'Lambda context must provide get_remaining_time_in_millis'
            end

            remaining_millis = context.get_remaining_time_in_millis
            unless remaining_millis.is_a?(Numeric)
              raise ArgumentError, 'Lambda context get_remaining_time_in_millis must return a number'
            end

            remaining_seconds = Float(remaining_millis) || raise(TypeError, 'Lambda remaining time must be numeric')
            shutdown_seconds = Float(shutdown_buffer) || raise(TypeError, 'shutdown_buffer must be numeric')
            unless remaining_seconds.finite? && shutdown_seconds.finite?
              raise ArgumentError, 'Lambda remaining time and shutdown_buffer must be finite'
            end

            work_time = (remaining_seconds / 1000.0) - shutdown_seconds
            if work_time <= 1
              raise 'Lambda timeout leaves too little time for work ' \
                    "(work_time=#{work_time}, shutdown_buffer=#{shutdown_buffer})"
            end

            if work_time < 5
              _log(logger, :warn,
                   'Lambda timeout leaves less than 5s for work after shutdown buffer ' \
                   "(work_time=#{work_time}, shutdown_buffer=#{shutdown_buffer})")
            end
            work_time
          end

          def _run_shutdown_hooks(hooks, logger)
            hooks.each do |hook|
              hook.call
            rescue StandardError => e
              _log_exception(logger, 'Lambda worker shutdown hook failed', e)
            end
          end

          def _cleanup_client(client, dependencies:, logger:)
            return unless client

            begin
              dependencies.fetch(:cleanup_client).call(client)
            rescue StandardError => e
              _log_exception(logger, 'Lambda worker client cleanup failed', e)
            end
          end

          def _cleanup_worker(worker, dependencies:, logger:)
            return unless worker

            begin
              dependencies.fetch(:cleanup_worker).call(worker)
            rescue StandardError => e
              _log_exception(logger, 'Lambda worker cleanup failed', e)
            end
          end

          def _cancel_shutdown_timer(timer)
            return unless timer

            if timer.respond_to?(:cancel)
              timer.cancel
            elsif timer.respond_to?(:kill)
              timer.kill
              timer.join unless timer == Thread.current
            end
          rescue StandardError
            nil
          end

          def _log_exception(logger, message, error)
            _log(logger, :error, "#{message}: #{error.message}")
          end

          def _log(logger, level, message)
            logger.public_send(level, message)
          rescue StandardError
            nil
          end

          def _default_dependencies
            {
              connect_client: Client.method(:connect),
              create_worker: Worker.method(:new),
              start_shutdown_timer: lambda do |delay, &block|
                Thread.new do
                  sleep(delay)
                  block.call
                end
              end,
              cleanup_client: lambda do |client|
                if client.respond_to?(:close)
                  client.close
                elsif client.respond_to?(:connection)
                  connection = client.connection
                  if connection.respond_to?(:close)
                    connection.close
                  elsif connection.respond_to?(:_close)
                    connection._close
                  end
                end
              end,
              # Steep cannot type the Symbol#to_proc shorthand here.
              cleanup_worker: lambda do |worker| # rubocop:disable Style/SymbolProc
                worker._close
              end,
              getenv: ->(name) { ENV.fetch(name, nil) },
              readable_file: ->(path) { File.file?(path) && File.readable?(path) },
              cwd: -> { Dir.pwd },
              load_client_options: nil
            }.freeze
          end
        end
      end
    end
  end
end

require 'temporalio/contrib/aws/lambda_worker/open_telemetry'
