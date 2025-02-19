# frozen_string_literal: true

require 'temporalio/activity'
require 'temporalio/cancellation'
require 'temporalio/converters/payload_converter'
require 'temporalio/worker/activity_executor'

module Temporalio
  module Testing
    # Test environment for testing activities.
    #
    # Users can create this environment and then use {run} to execute activities on it. Often, since mutable things like
    # cancellation can be set, users create this for each activity that is run. There is no real performance penalty for
    # creating an environment for every run.
    class ActivityEnvironment
      # @return [Activity::Info] The activity info used by default. This is frozen, but can be dup'd and mutated to pass
      #   in to {initialize}.
      def self.default_info
        @default_info ||= Activity::Info.new(
          activity_id: 'test',
          activity_type: 'unknown',
          attempt: 1,
          current_attempt_scheduled_time: Time.at(0),
          heartbeat_details: [],
          heartbeat_timeout: nil,
          local?: false,
          schedule_to_close_timeout: 1.0,
          scheduled_time: Time.at(0),
          start_to_close_timeout: 1.0,
          started_time: Time.at(0),
          task_queue: 'test',
          task_token: String.new('test', encoding: Encoding::ASCII_8BIT),
          workflow_id: 'test',
          workflow_namespace: 'default',
          workflow_run_id: 'test-run',
          workflow_type: 'test'
        ).freeze
      end

      # Create a test environment for activities.
      #
      # @param info [Activity::Info] Value for {Activity::Context#info}.
      # @param on_heartbeat [Proc(Array), nil] Proc that is called with all heartbeat details when
      #   {Activity::Context#heartbeat} is called.
      # @param cancellation [Cancellation] Value for {Activity::Context#cancellation}.
      # @param worker_shutdown_cancellation [Cancellation] Value for {Activity::Context#worker_shutdown_cancellation}.
      # @param payload_converter [Converters::PayloadConverter] Value for {Activity::Context#payload_converter}.
      # @param logger [Logger] Value for {Activity::Context#logger}.
      # @param activity_executors [Hash<Symbol, Worker::ActivityExecutor>] Executors that activities can run within.
      # @param metric_meter [Metric::Meter, nil] Value for {Activity::Context#metric_meter}, or nil to raise when
      #   called.
      # @param client [Client, nil] Value for {Activity::Context#client}, or nil to raise when called.
      def initialize(
        info: ActivityEnvironment.default_info,
        on_heartbeat: nil,
        cancellation: Cancellation.new,
        worker_shutdown_cancellation: Cancellation.new,
        payload_converter: Converters::PayloadConverter.default,
        logger: Logger.new(nil),
        activity_executors: Worker::ActivityExecutor.defaults,
        metric_meter: nil,
        client: nil
      )
        @info = info
        @on_heartbeat = on_heartbeat
        @cancellation = cancellation
        @worker_shutdown_cancellation = worker_shutdown_cancellation
        @payload_converter = payload_converter
        @logger = logger
        @activity_executors = activity_executors
        @metric_meter = metric_meter
        @client = client
      end

      # Run an activity and returns its result or raises its exception.
      #
      # @param activity [Activity::Definition, Class<Activity::Definition>, Activity::Definition::Info] Activity to run.
      # @param args [Array<Object>] Arguments to the activity.
      # @return Activity result.
      def run(activity, *args)
        defn = Activity::Definition::Info.from_activity(activity)
        executor = @activity_executors[defn.executor]
        raise ArgumentError, "Unknown executor: #{defn.executor}" if executor.nil?

        queue = Queue.new
        executor.execute_activity(defn) do
          Activity::Context._current_executor = executor
          executor.set_activity_context(defn, Context.new(
                                                info: @info.dup,
                                                instance:
                                                  defn.instance.is_a?(Proc) ? defn.instance.call : defn.instance,
                                                on_heartbeat: @on_heartbeat,
                                                cancellation: @cancellation,
                                                worker_shutdown_cancellation: @worker_shutdown_cancellation,
                                                payload_converter: @payload_converter,
                                                logger: @logger,
                                                metric_meter: @metric_meter,
                                                client: @client
                                              ))
          queue.push([defn.proc.call(*args), nil])
        rescue Exception => e # rubocop:disable Lint/RescueException -- Intentionally capturing all exceptions
          queue.push([nil, e])
        ensure
          executor.set_activity_context(defn, nil)
          Activity::Context._current_executor = nil
        end

        result, err = queue.pop
        raise err unless err.nil?

        result
      end

      # @!visibility private
      class Context < Activity::Context
        attr_reader :info, :instance, :cancellation, :worker_shutdown_cancellation, :payload_converter, :logger

        def initialize( # rubocop:disable Lint/MissingSuper
          info:,
          instance:,
          on_heartbeat:,
          cancellation:,
          worker_shutdown_cancellation:,
          payload_converter:,
          logger:,
          metric_meter:,
          client:
        )
          @info = info
          @instance = instance
          @on_heartbeat = on_heartbeat
          @cancellation = cancellation
          @worker_shutdown_cancellation = worker_shutdown_cancellation
          @payload_converter = payload_converter
          @logger = logger
          @metric_meter = metric_meter
          @client = client
        end

        # @!visibility private
        def heartbeat(*details)
          @on_heartbeat&.call(details)
        end

        # @!visibility private
        def metric_meter
          @metric_meter or raise 'No metric meter configured in this test environment'
        end

        # @!visibility private
        def client
          @client or raise 'No client configured in this test environment'
        end
      end

      private_constant :Context
    end
  end
end
