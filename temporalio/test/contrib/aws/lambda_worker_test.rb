# frozen_string_literal: true

require 'temporalio/contrib/aws/lambda_worker'
require 'test'
require 'tmpdir'

module Contrib
  module Aws
    class LambdaWorkerTest < Test
      LambdaWorker = Temporalio::Contrib::Aws::LambdaWorker
      Version = Temporalio::WorkerDeploymentVersion.new(deployment_name: 'lambda-test', build_id: 'v1')
      class Context
        attr_reader :aws_request_id, :invoked_function_arn

        def initialize(aws_request_id, invoked_function_arn, remaining_millis)
          @aws_request_id = aws_request_id
          @invoked_function_arn = invoked_function_arn
          @remaining_millis = remaining_millis
        end

        def get_remaining_time_in_millis # rubocop:disable Naming/AccessorMethodName
          @remaining_millis
        end
      end

      class Timer
        attr_reader :killed, :joined

        def kill
          @killed = true
        end

        def join
          @joined = true
        end
      end

      class Connection
        attr_reader :closed

        def _close
          @closed = true
        end
      end

      class Client
        attr_reader :connection

        def initialize(connection)
          @connection = connection
        end
      end

      class Worker
        attr_reader :closed, :cancellation
        attr_writer :wait_for_cancellation

        def run(cancellation:, shutdown_signals:)
          raise 'Unexpected signal handlers' unless shutdown_signals.empty?

          @cancellation = cancellation
          cancellation.wait if @wait_for_cancellation
        end

        def _close
          @closed = true
        end
      end

      def setup
        super
        @clock = 0.0
        @timer = Timer.new
        @client = Client.new(Connection.new)
        @worker = Worker.new
        @client_options = []
        @worker_options = []
        @delays = []
        @cancel = nil
        @getenv = {}
        @dependencies = LambdaWorker.send(:_default_dependencies).merge(
          clock: -> { @clock },
          getenv: ->(name) { @getenv[name] },
          load_client_options: ->(_path) { [['localhost:7233', 'default'], {}] },
          connect_client: lambda do |*_args, **options|
            @client_options << options
            @client
          end,
          create_worker: lambda do |**options|
            @worker_options << options
            @worker
          end,
          start_shutdown_timer: lambda do |delay, &cancel|
            @delays << delay
            @cancel = cancel
            @timer
          end
        )
      end

      def test_warm_invocations_reconfigure_and_enforce_deployment
        calls = []
        handler = handler() do |options, context|
          calls << context.aws_request_id
          options.with(task_queue: context.aws_request_id)
        end
        handler.call({}, context('first'))
        handler.call(event: {}, context: context('second'))

        assert_equal %w[first second], calls
        assert_equal(%w[first second], @worker_options.map { |options| options[:task_queue] })
        assert_equal(['first@arn:test', 'second@arn:test'], @client_options.map { |options| options[:identity] })
        assert @timer.killed
        assert @timer.joined
        assert @client.connection.closed
        assert @worker.closed
      end

      def test_setup_consumes_work_budget
        handler = handler() do |options, _context|
          @clock = 3.0
          options
        end
        handler.call({}, context)
        assert_equal [10.0], @delays

        @clock = 0.0
        handler = handler() do |options, _context|
          @clock = 14.0
          options
        end
        assert_raises(RuntimeError) { handler.call({}, context) }
        assert_equal 1, @client_options.length
      end

      def test_connection_exhausting_budget_does_not_start_worker
        connect = @dependencies.fetch(:connect_client)
        @dependencies[:connect_client] = lambda do |*args, **kwargs|
          @cancel.call
          connect.call(*args, **kwargs)
        end
        handler.call({}, context)
        assert_empty @worker_options
        assert @client.connection.closed
        assert @timer.joined
      end

      def test_failure_does_not_skip_hooks_or_mask_error
        logger = Logger.new(StringIO.new)
        hooks = []
        @dependencies[:create_worker] = ->(**_options) { raise 'worker failed' }
        handler = handler(
          client_options: { logger: },
          shutdown_hooks: [
            ->(_remaining) { raise 'hook failed' },
            ->(remaining) { hooks << remaining }
          ]
        )
        error = assert_raises(RuntimeError) { handler.call({}, context) }
        assert_equal 'worker failed', error.message
        assert_equal [20.0], hooks
        assert @client.connection.closed
        assert @timer.joined
        assert_raises(RuntimeError) { handler.call({}, context) }
      end

      def test_options_copy_collections_and_validate_shutdown_buffer
        metadata = { 'test' => ['one'] }
        options = LambdaWorker::Options.new(client_options: { rpc_metadata: metadata })
        metadata['test'] << 'two'
        assert_equal ['one'], options.client_options[:rpc_metadata]['test']
        assert options.client_options[:rpc_metadata]['test'].frozen?
        assert_equal 'queue', options.with(task_queue: 'queue').task_queue
        [Float::INFINITY, Float::NAN, -1].each do |buffer|
          assert_raises(ArgumentError) { LambdaWorker::Options.new(shutdown_buffer: buffer) }
        end
      end

      def test_environment_is_resolved_per_invocation
        @getenv['TEMPORAL_TASK_QUEUE'] = 'one'
        handler = handler(task_queue: nil)
        handler.call({}, context)
        @getenv['TEMPORAL_TASK_QUEUE'] = 'two'
        handler.call({}, context)
        assert_equal(%w[one two], @worker_options.map { |options| options[:task_queue] })
      end

      def test_insufficient_budget_and_invalid_context
        assert_raises(RuntimeError) { handler.call({}, context('test', remaining: 7_000)) }
        assert_raises(ArgumentError) { handler.call({}, context('test', remaining: Float::NAN)) }
        assert_raises(ArgumentError) { handler.call({}, context('')) }
        assert_empty @client_options
      end

      def test_shutdown_timer_is_joined
        timer = LambdaWorker.send(:_default_dependencies).fetch(:start_shutdown_timer).call(60) { flunk 'Timer fired' }
        timer.kill
        timer.join
        refute timer.alive?
      ensure
        timer&.kill&.join
      end

      def test_production_timer_cancels_and_cleans_up
        @worker.wait_for_cancellation = true
        @dependencies[:start_shutdown_timer] = LambdaWorker.send(:_default_dependencies).fetch(:start_shutdown_timer)
        logger = Logger.new(StringIO.new)
        Timeout.timeout(5) do
          handler(shutdown_buffer: 0, client_options: { logger: }).call({}, context('request', remaining: 100))
        end
        assert @worker.cancellation&.canceled?
        assert @worker.closed
        assert @client.connection.closed
      end

      def test_lambda_config_path_precedence
        Dir.mktmpdir do |dir| # steep:ignore
          path = File.join(dir, 'temporal.toml')
          File.write(path, '')
          @getenv['LAMBDA_TASK_ROOT'] = dir
          paths = []
          @dependencies[:load_client_options] = lambda do |selected_path|
            paths << selected_path
            [['localhost:7233', 'default'], {}]
          end
          handler.call({}, context)
          @getenv['TEMPORAL_CONFIG_FILE'] = '/explicit/config.toml'
          handler.call({}, context)
          assert_equal [path, '/explicit/config.toml'], paths
        end
      end

      def test_static_version_validation
        ['', '   '].each do |name|
          assert_raises(ArgumentError) do
            LambdaWorker.define(Temporalio::WorkerDeploymentVersion.new(deployment_name: name, build_id: 'v1'))
          end
        end
      end

      private

      def handler(**options, &)
        LambdaWorker.send(
          :_define, Version,
          options: LambdaWorker::Options.new(task_queue: 'queue', **options),
          dependencies: @dependencies, &
        )
      end

      def context(id = 'request', remaining: 20_000)
        Context.new(id, 'arn:test', remaining)
      end
    end
  end
end
