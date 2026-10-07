# frozen_string_literal: true

require 'temporalio/contrib/aws/lambda_worker'
require 'temporalio/simple_plugin'
require 'test'

module Contrib
  module Aws
    class LambdaWorkerTest < Test
      LambdaWorker = Temporalio::Contrib::Aws::LambdaWorker
      Version = Temporalio::WorkerDeploymentVersion.new(deployment_name: 'lambda-worker-test', build_id: 'build-1')

      class FakeContext
        attr_reader :aws_request_id, :invoked_function_arn

        def initialize(remaining_millis: 20_000, aws_request_id: 'request-1',
                       invoked_function_arn: 'arn:aws:lambda:test')
          @remaining_millis = remaining_millis
          @aws_request_id = aws_request_id
          @invoked_function_arn = invoked_function_arn
        end

        # AWS fixes this method name as part of the Lambda context interface.
        def get_remaining_time_in_millis # rubocop:disable Naming/AccessorMethodName
          @remaining_millis
        end
      end

      class FakeLogger < Logger
        attr_reader :warnings, :errors

        def initialize
          super($stdout, level: Logger::WARN)
          @warnings = []
          @errors = []
        end

        def warn(message)
          @warnings << message
        end

        def error(message)
          @errors << message
        end
      end

      class FakeTimer
        attr_reader :cancelled

        def cancel
          @cancelled = true
        end
      end

      class FakeClient
        attr_reader :closed

        def close
          @closed = true
        end
      end

      class FakeSdkConnection
        attr_reader :closed

        def _close
          @closed = true
        end
      end

      class FakeSdkClient
        attr_reader :connection

        def initialize
          @connection = FakeSdkConnection.new
        end
      end

      class FakeWorker
        attr_reader :cancellation, :closed

        def initialize(events:, error: nil)
          @events = events
          @error = error
        end

        def run(cancellation:)
          @cancellation = cancellation
          @events << :worker_run
          raise @error if @error
        end

        def _close
          @closed = true
          @events << :worker_cleanup
        end
      end

      class PluginActivity < Temporalio::Activity::Definition
        def execute; end
      end

      class PluginWorkflow < Temporalio::Workflow::Definition
        def execute; end
      end

      class DeploymentOptionsCarrier
        attr_reader :deployment_options, :identity, :disable_eager_activity_execution

        def initialize(deployment_options:, identity: nil, disable_eager_activity_execution: false)
          @deployment_options = deployment_options
          @identity = identity
          @disable_eager_activity_execution = disable_eager_activity_execution
        end

        def with(
          deployment_options: @deployment_options,
          identity: @identity,
          disable_eager_activity_execution: @disable_eager_activity_execution
        )
          self.class.new(deployment_options:, identity:, disable_eager_activity_execution:)
        end
      end

      class IncompleteCombinedPlugin
        include Temporalio::Client::Plugin
        include Temporalio::Worker::Plugin

        def name
          'incomplete-combined-plugin'
        end

        def configure_client(options)
          options
        end

        def connect_client(options, next_call)
          next_call.call(options)
        end
      end

      class IdentityOverridePlugin
        include Temporalio::Client::Plugin

        def name
          'identity-override-plugin'
        end

        def configure_client(options)
          options
        end

        def connect_client(options, next_call)
          next_call.call(options.with(identity: 'plugin-identity'))
        end
      end

      class DeploymentOverridePlugin
        include Temporalio::Worker::Plugin

        def initialize(deployment_options)
          @deployment_options = deployment_options
        end

        def name
          'deployment-override-plugin'
        end

        def configure_worker(options)
          options.with(
            deployment_options: @deployment_options,
            identity: 'plugin-identity',
            disable_eager_activity_execution: false
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

      class RunFailurePlugin
        include Temporalio::Worker::Plugin

        def name
          'run-failure-plugin'
        end

        def configure_worker(options)
          options
        end

        def run_worker(_options, _next_call)
          raise 'run plugin failed'
        end

        def configure_workflow_replayer(options)
          options
        end

        def with_workflow_replay_worker(options, next_call)
          next_call.call(options)
        end
      end

      def test_options_apply_lambda_defaults_and_freeze_collections
        activities = [PluginActivity]
        nested_worker_option = ['mutable']
        worker_options = { max_cached_workflows: 99, nested: nested_worker_option }
        options = LambdaWorker::Options.new(
          task_queue: 'queue',
          activities:,
          workflows: [PluginWorkflow],
          client_options: { rpc_metadata: { 'x-test' => 'value' } },
          worker_options:,
          shutdown_hooks: [-> {}],
          plugins: []
        )

        assert options.frozen?
        assert options.activities.frozen?
        assert options.client_options.frozen?
        assert options.client_options[:rpc_metadata].frozen?
        assert options.worker_options.frozen?
        assert options.worker_options[:nested].frozen?
        assert_equal 99, options.worker_options[:max_cached_workflows]
        assert_equal true, options.worker_options[:disable_eager_activity_execution]
        tuner = options.worker_options[:tuner]
        assert_equal 10, tuner.workflow_slot_supplier.slots
        assert_equal 2, tuner.activity_slot_supplier.slots
        assert_equal 2, tuner.local_activity_slot_supplier.slots
        assert_equal 2, options.worker_options[:workflow_task_poller_behavior].maximum
        assert_equal 1, options.worker_options[:activity_task_poller_behavior].maximum
        assert_equal 5, options.worker_options[:graceful_shutdown_period]
        assert_equal 7, options.shutdown_buffer
        assert_raises(ArgumentError) do
          LambdaWorker::Options.new(task_queue: 'queue', activities: [PluginActivity], shutdown_buffer: Float::NAN)
        end
        assert_raises(ArgumentError) do
          LambdaWorker::Options.new(task_queue: 'queue', activities: [PluginActivity], shutdown_buffer: Float::INFINITY)
        end

        activities << PluginActivity
        nested_worker_option << 'changed'
        assert_equal 1, options.activities.length
        assert_equal ['mutable'], options.worker_options[:nested]
        assert_raises(FrozenError) { options.activities << PluginActivity }
      end

      def test_options_with_rebuilds_immutable_collections
        options = LambdaWorker::Options.new(task_queue: 'one', activities: [PluginActivity])
        updated = options.with(
          task_queue: 'two',
          client_connect_options: { rpc_metadata: { 'x-test' => 'value' } }
        )

        assert_equal 'one', options.task_queue
        assert_equal 'two', updated.task_queue
        assert updated.client_options.frozen?
        assert updated.client_options[:rpc_metadata].frozen?
        assert_equal({ 'x-test' => 'value' }, updated.client_connect_options[:rpc_metadata])
      end

      def test_options_derive_poller_behavior_from_overridden_poll_counts
        options = LambdaWorker::Options.new(
          task_queue: 'queue',
          activities: [PluginActivity],
          worker_options: {
            max_concurrent_workflow_task_polls: 3,
            max_concurrent_activity_task_polls: 4
          }
        )

        assert_equal 3, options.worker_options[:workflow_task_poller_behavior].maximum
        assert_equal 4, options.worker_options[:activity_task_poller_behavior].maximum
      end

      def test_define_validates_static_configuration
        error = assert_raises(ArgumentError) do
          define_handler(Temporalio::WorkerDeploymentVersion.new(deployment_name: '', build_id: 'build'), base_options)
        end
        assert_includes error.message, 'deployment_name'

        error = assert_raises(ArgumentError) do
          define_handler(Version, base_options(task_queue: nil), env: {})
        end
        assert_includes error.message, 'TEMPORAL_TASK_QUEUE'
      end

      def test_define_validates_combined_plugins_for_worker_protocol
        error = assert_raises(ArgumentError) do
          define_handler(Version, base_options(plugins: [IncompleteCombinedPlugin.new]))
        end

        assert_includes error.message, 'worker plugin'
      end

      def test_define_allows_plugin_only_worker_registration
        # @type var captured_worker: Temporalio::Worker?
        captured_worker = nil
        plugin = Temporalio::SimplePlugin.new(
          name: 'registration-plugin',
          activities: [PluginActivity],
          run_context: ->(_options, _next_call) {}
        )
        dependencies = LambdaWorker.send(:_default_dependencies).merge(
          create_worker: lambda do |**worker_options|
            captured_worker = Temporalio::Worker.new(**worker_options)
          end,
          start_shutdown_timer: ->(_delay, &_block) { FakeTimer.new },
          getenv: ->(_name) {},
          readable_file: ->(_path) { false },
          cwd: -> { '/work' },
          load_client_options: lambda do |_path|
            [[env.client.connection.target_host, env.client.namespace], {}]
          end
        )
        handler = LambdaWorker.send(
          :_define,
          Version,
          options: LambdaWorker::Options.new(task_queue: "tq-#{SecureRandom.uuid}", plugins: [plugin]),
          dependencies:
        )

        handler.call({}, FakeContext.new)

        worker = captured_worker
        raise 'worker was not created' unless worker

        assert_equal [PluginActivity], worker.options.activities
        assert worker._bridge_worker.finalized?
      end

      def test_target_host_override_removes_address_alias
        handler, captures = define_handler(
          Version,
          base_options(client_options: {
                         target_host: 'target.example:7233',
                         address: 'alias.example:7233',
                         namespace: 'override-namespace'
                       })
        )

        handler.call({}, FakeContext.new)

        assert_equal ['target.example:7233', 'override-namespace'], captures[:client_connect_args].first
        refute captures[:client_options].first.key?(:target_host)
        refute captures[:client_options].first.key?(:address)
        refute captures[:client_options].first.key?(:namespace)
      end

      def test_api_key_override_restores_client_tls_default
        _, env_options = Temporalio::EnvConfig::ClientConfigProfile.new.to_client_connect_options
        handler, captures = define_handler(
          Version,
          base_options(client_options: { api_key: 'api-key' }),
          loaded_client_options: env_options
        )

        handler.call({}, FakeContext.new)

        connect_options = captures[:client_options].first
        assert_equal 'api-key', connect_options[:api_key]
        refute connect_options.key?(:tls)

        _, disabled_env_options = Temporalio::EnvConfig::ClientConfigProfile.new(
          tls: Temporalio::EnvConfig::ClientConfigTLS.new(disabled: true)
        ).to_client_connect_options
        disabled_handler, disabled_captures = define_handler(
          Version,
          base_options(client_options: { api_key: 'api-key' }),
          loaded_client_options: disabled_env_options
        )
        disabled_handler.call({}, FakeContext.new)
        assert_equal false, disabled_captures[:client_options].first[:tls]

        explicit_handler, explicit_captures = define_handler(
          Version,
          base_options(client_options: { api_key: 'api-key', tls: false }),
          loaded_client_options: { tls: false }
        )
        explicit_handler.call({}, FakeContext.new)
        assert_equal false, explicit_captures[:client_options].first[:tls]
      end

      def test_define_uses_config_path_priority_and_materializes_environment
        selected_paths = []
        env = {
          'TEMPORAL_CONFIG_FILE' => '/configured/temporal.toml',
          'LAMBDA_TASK_ROOT' => '/lambda',
          'TEMPORAL_TASK_QUEUE' => 'queue-from-environment'
        }
        handler, captures = define_handler(
          Version,
          base_options(task_queue: nil),
          env:,
          readable_paths: Set.new(['/lambda/temporal.toml', '/work/temporal.toml']),
          selected_paths:
        )

        assert_equal ['/configured/temporal.toml'], selected_paths
        env['TEMPORAL_TASK_QUEUE'] = 'changed-after-definition'
        handler.call({}, FakeContext.new)
        assert_equal 'queue-from-environment', captures[:worker_options].first[:task_queue]

        selected_paths.clear
        define_handler(
          Version,
          base_options,
          env: { 'LAMBDA_TASK_ROOT' => '/lambda' },
          readable_paths: Set.new(['/lambda/temporal.toml', '/work/temporal.toml']),
          selected_paths:
        )
        assert_equal ['/lambda/temporal.toml'], selected_paths

        selected_paths.clear
        define_handler(
          Version,
          base_options,
          env: {},
          readable_paths: Set.new(['/work/temporal.toml']),
          selected_paths:
        )
        assert_equal ['/work/temporal.toml'], selected_paths

        selected_paths.clear
        define_handler(Version, base_options, env: {}, selected_paths:)
        assert_equal [nil], selected_paths
      end

      def test_handler_recreates_client_and_worker_with_lambda_identity
        handler, captures = define_handler(Version, base_options)
        first_context = FakeContext.new(aws_request_id: 'request-1', invoked_function_arn: 'arn:first')
        second_context = FakeContext.new(aws_request_id: 'request-2', invoked_function_arn: 'arn:second')

        handler.call({}, first_context)
        handler.call({}, second_context)

        assert_equal 2, captures[:client_options].length
        assert_equal 2, captures[:worker_options].length
        assert_equal 'request-1@arn:first', captures[:client_options][0][:identity]
        assert_equal 'request-2@arn:second', captures[:client_options][1][:identity]
        assert_equal 'request-1@arn:first', captures[:worker_options][0][:identity]
        assert_equal 'request-2@arn:second', captures[:worker_options][1][:identity]
        deployment_options = captures[:worker_options][0][:deployment_options]
        assert_equal Version, deployment_options.version
        assert deployment_options.use_worker_versioning
        assert_equal Temporalio::VersioningBehavior::PINNED, deployment_options.default_versioning_behavior
      end

      def test_handler_preserves_configured_default_versioning_behavior
        handler, captures = define_handler(
          Version,
          base_options(default_versioning_behavior: Temporalio::VersioningBehavior::AUTO_UPGRADE)
        )

        handler.call({}, FakeContext.new)

        deployment = captures[:worker_options].first[:deployment_options]
        assert_equal Version, deployment.version
        assert deployment.use_worker_versioning
        assert_equal Temporalio::VersioningBehavior::AUTO_UPGRADE, deployment.default_versioning_behavior
      end

      def test_handler_joins_shutdown_timer
        timer = LambdaWorker.send(:_default_dependencies).fetch(:start_shutdown_timer).call(60) do
          flunk 'Shutdown timer fired after cancellation'
        end

        LambdaWorker.send(:_cancel_shutdown_timer, timer)

        refute timer.alive?
      ensure
        timer&.kill&.join
      end

      def test_handler_runs_hooks_on_connection_failure
        events = []
        timer = FakeTimer.new
        handler = LambdaWorker.send(
          :_define,
          Version,
          options: base_options(shutdown_hooks: [-> { events << :hook }]),
          dependencies: LambdaWorker.send(:_default_dependencies).merge(
            load_client_options: ->(_path) { [['temporal.example:7233', 'namespace'], {}] },
            connect_client: ->(*_args, **_kwargs) { raise 'connect failed' },
            start_shutdown_timer: ->(_delay, &_block) { timer }
          )
        )

        error = assert_raises(RuntimeError) { handler.call({}, FakeContext.new) }

        assert_equal 'connect failed', error.message
        assert_equal [:hook], events
        assert timer.cancelled
      end

      def test_handler_starts_shutdown_timer_before_client_setup
        events = []
        handler, = define_handler(
          Version,
          base_options,
          events:,
          timer_calls_block: false,
          record_invocation_order: true
        )

        handler.call({}, FakeContext.new)

        assert_equal %i[shutdown_timer client_connect worker_run worker_cleanup cleanup], events
      end

      def test_handler_materializes_deployment_version
        deployment_name = 'lambda-worker-test'.dup
        build_id = 'build-1'.dup
        version = Temporalio::WorkerDeploymentVersion.new(deployment_name:, build_id:)
        handler, captures = define_handler(version, base_options)
        deployment_name << '-changed'
        build_id << '-changed'

        handler.call({}, FakeContext.new)

        defined_version = captures[:worker_options].first[:deployment_options].version
        assert_equal 'lambda-worker-test', defined_version.deployment_name
        assert_equal 'build-1', defined_version.build_id
      end

      def test_handler_overrides_identity_and_deployment_options
        replacement_version = Temporalio::WorkerDeploymentVersion.new(deployment_name: 'other', build_id: 'other')
        handler, captures = define_handler(
          Version,
          base_options(
            client_options: { identity: 'not-the-lambda' },
            worker_options: {
              identity: 'not-the-lambda',
              deployment_options: Temporalio::Worker::DeploymentOptions.new(version: replacement_version)
            }
          )
        )

        handler.call({}, FakeContext.new)

        assert_equal 'request-1@arn:aws:lambda:test', captures[:client_options][0][:identity]
        assert_equal 'request-1@arn:aws:lambda:test', captures[:worker_options][0][:identity]
        assert_equal Version, captures[:worker_options][0][:deployment_options].version
      end

      def test_handler_enforces_client_identity_after_client_plugins
        handler, captures = define_handler(
          Version,
          base_options(plugins: [IdentityOverridePlugin.new])
        )
        handler.call({}, FakeContext.new)

        overriding_plugin, enforcement_plugin = captures[:client_options].first[:plugins]
        connection = Temporalio::Client::Connection.new(target_host: 'temporal.example:7233', lazy_connect: true)
        connected_options = connection.options
        overriding_plugin.connect_client(
          connection.options,
          lambda do |overridden_options|
            enforcement_plugin.connect_client(
              overridden_options,
              lambda do |final_options|
                connected_options = final_options
                connection
              end
            )
          end
        )

        assert_equal 'request-1@arn:aws:lambda:test', connected_options.identity
      end

      def test_handler_enforces_deployment_options_after_worker_plugins
        replacement_version = Temporalio::WorkerDeploymentVersion.new(deployment_name: 'other', build_id: 'other')
        replacement = Temporalio::Worker::DeploymentOptions.new(version: replacement_version)
        handler, captures = define_handler(
          Version,
          base_options(plugins: [DeploymentOverridePlugin.new(replacement)])
        )

        handler.call({}, FakeContext.new)

        configured_options = captures[:worker_options].first[:plugins].reduce(
          DeploymentOptionsCarrier.new(deployment_options: replacement, identity: 'untrusted')
        ) { |current, plugin| plugin.configure_worker(current) }
        deployment_options = configured_options.deployment_options
        assert_equal Version, deployment_options.version
        assert deployment_options.use_worker_versioning
        assert_equal Temporalio::VersioningBehavior::PINNED, deployment_options.default_versioning_behavior
        assert_equal 'request-1@arn:aws:lambda:test', configured_options.identity
        assert configured_options.disable_eager_activity_execution
      end

      def test_handler_reserves_shutdown_buffer_and_warns_for_short_work_time
        logger = FakeLogger.new
        handler, captures = define_handler(
          Version,
          base_options(client_options: { logger: }, shutdown_buffer: 0.5),
          timer_calls_block: false
        )

        handler.call({}, FakeContext.new(remaining_millis: 2_000))

        assert_in_delta 1.5, captures[:timer_delays].first
        assert_equal 1, logger.warnings.length
        assert_includes logger.warnings.first, 'less than 5s'
        assert captures[:timers].first.cancelled
      end

      def test_handler_rejects_deadlines_with_at_most_one_second_of_work
        handler, captures = define_handler(Version, base_options)

        [7_999, 8_000].each do |remaining_millis|
          error = assert_raises(RuntimeError) do
            handler.call({}, FakeContext.new(remaining_millis:))
          end
          assert_includes error.message, 'too little time'
        end

        assert_empty captures[:client_options]
      end

      def test_handler_cancels_worker_then_runs_hooks_and_cleanup_without_masking_worker_error
        events = []
        logger = FakeLogger.new
        worker_error = RuntimeError.new('worker failed')
        options = base_options(
          client_options: { logger: },
          shutdown_hooks: [
            lambda {
              events << :first_hook
              raise 'first hook failed'
            },
            -> { events << :second_hook }
          ]
        )
        handler, captures = define_handler(
          Version,
          options,
          events:,
          worker_error:,
          cleanup_error: RuntimeError.new('cleanup failed')
        )

        error = assert_raises(RuntimeError) { handler.call({}, FakeContext.new) }

        assert_same worker_error, error
        assert_equal %i[worker_run worker_cleanup first_hook second_hook cleanup], events
        assert captures[:workers].first.cancellation.canceled?
        assert captures[:workers].first.closed
        assert_equal 2, logger.errors.length
        assert_includes logger.errors.first, 'shutdown hook failed'
        assert_includes logger.errors.last, 'client cleanup failed'
      end

      def test_default_client_cleanup_uses_internal_connection_close
        client = FakeSdkClient.new
        cleanup_client = LambdaWorker.send(:_default_dependencies).fetch(:cleanup_client)

        cleanup_client.call(client)

        assert client.connection.closed
      end

      def test_handler_finalizes_worker_when_run_plugin_fails_before_polling
        # @type var captured_worker: Temporalio::Worker?
        captured_worker = nil
        plugin = RunFailurePlugin.new
        handler = LambdaWorker.send(
          :_define,
          Version,
          options: LambdaWorker::Options.new(task_queue: 'queue', activities: [PluginActivity], plugins: [plugin]),
          dependencies: {
            connect_client: ->(*_args, **_kwargs) { env.client },
            create_worker: lambda do |**worker_options|
              captured_worker = Temporalio::Worker.new(**worker_options)
            end,
            start_shutdown_timer: ->(_delay, &_block) { Object.new },
            # Steep cannot type the Symbol#to_proc shorthand here.
            cleanup_worker: lambda do |worker| # rubocop:disable Style/SymbolProc
              worker._close
            end,
            cleanup_client: ->(_client) {},
            getenv: ->(_name) {},
            readable_file: ->(_path) { false },
            cwd: -> { '/work' },
            load_client_options: ->(_path) { [['temporal.example:7233', 'namespace'], {}] }
          }
        )

        error = assert_raises(RuntimeError) { handler.call({}, FakeContext.new) }

        assert_equal 'run plugin failed', error.message
        worker = captured_worker
        raise 'worker was not created' unless worker

        assert worker._bridge_worker.finalized?
        worker._close
      end

      private

      def base_options(**kwargs)
        LambdaWorker::Options.new(task_queue: 'queue',
                                  activities: [PluginActivity], **kwargs)
      end

      def define_handler(
        version,
        options,
        env: { 'TEMPORAL_TASK_QUEUE' => 'queue-from-environment' },
        readable_paths: Set.new,
        selected_paths: [],
        events: [],
        worker_error: nil,
        cleanup_error: nil,
        timer_calls_block: true,
        record_invocation_order: false,
        loaded_client_options: {}
      )
        captures = {
          client_connect_args: [],
          client_options: [],
          worker_options: [],
          workers: [],
          timer_delays: [],
          timers: []
        }
        dependencies = {
          connect_client: lambda do |*client_connect_args, **client_options|
            events << :client_connect if record_invocation_order
            captures[:client_connect_args] << client_connect_args
            captures[:client_options] << client_options
            FakeClient.new
          end,
          create_worker: lambda do |**worker_options|
            captures[:worker_options] << worker_options
            worker = FakeWorker.new(events:, error: worker_error)
            captures[:workers] << worker
            worker
          end,
          start_shutdown_timer: lambda do |delay, &block|
            events << :shutdown_timer if record_invocation_order
            captures[:timer_delays] << delay
            block.call if timer_calls_block
            FakeTimer.new.tap { |timer| captures[:timers] << timer }
          end,
          cleanup_client: lambda do |client|
            events << :cleanup
            client.close
            raise cleanup_error if cleanup_error
          end,
          # Steep cannot type the Symbol#to_proc shorthand here.
          cleanup_worker: lambda do |worker| # rubocop:disable Style/SymbolProc
            worker._close
          end,
          getenv: ->(name) { env[name] },
          readable_file: ->(path) { readable_paths.include?(path) },
          cwd: -> { '/work' },
          load_client_options: lambda do |path|
            selected_paths << path
            [['temporal.example:7233', 'namespace'], loaded_client_options]
          end
        }
        [LambdaWorker.send(:_define, version, options:, dependencies:), captures]
      end
    end
  end
end
