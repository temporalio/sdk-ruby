# frozen_string_literal: true

require 'temporalio/client'
require 'temporalio/worker'

module Temporalio
  # Plugin that implements both {Client::Plugin} and {Worker::Plugin} and provides a simplified common set of settings
  # for configuring both.
  #
  # WARNING: Plugins are experimental.
  class SimplePlugin
    include Client::Plugin
    include Worker::Plugin

    Options = Data.define(
      :name,
      :data_converter,
      :client_interceptors,
      :activities,
      :workflows,
      :worker_interceptors,
      :workflow_failure_exception_types,
      :run_context
    )

    # Options as returned from {options} representing the options passed to the constructor.
    class Options; end # rubocop:disable Lint/EmptyClass

    # @return [Options] Frozen options for this plugin which has the same attributes as {initialize}.
    attr_reader :options

    # Create a simple plugin.
    #
    # @param name [String] Required string name for this plugin.
    # @param data_converter [Converters::DataConverter, Proc, nil] Data converter to apply to clients and workflow
    #   replayers. This can be a proc that accepts the existing data converter and returns a new one.
    # @param client_interceptors [Array<Client::Integerceptor>, Proc, nil] Client interceptors that are appended to the
    #   existing client set (which means if they implement worker interceptors they are applied for the workers too). A
    #   proc can be provided that accepts the existing array and returns a new one.
    # @param activities [Array<Activity::Definition, Class<Activity::Definition>, Activity::Definition::Info>, Proc,
    #   nil] Activities to append to each worker activity set. A proc can be provided that accepts the existing array
    #   and returns a new one.
    # @param workflows [Array<Class<Workflow::Definition>>, Proc, nil] Workflows to append to each worker workflow set.
    #   A proc can be provided that accepts the existing array and returns a new one.
    # @param worker_interceptors [Array<Interceptor::Activity, Interceptor::Workflow>, Proc, nil] Worker interceptors
    #   that are appended to the existing worker or workflow replayer set. A proc can be provided that accepts the
    #   existing array and returns a new one.
    # @param workflow_failure_exception_types [Array<Class<Exception>>] Workflow failure exception types that are
    #   appended to the existing worker or workflow replayer set. A proc can be provided that accepts the existing array
    #   and returns a new one.
    # @param run_context [Proc, nil] A proc that intercepts both {run_worker} or {with_workflow_replay_worker}. The proc
    #   should accept two positional parameters: options and next_call. The options are either
    #   {Worker::Plugin::RunWorkerOptions} or {Worker::Plugin::WithWorkflowReplayWorkerOptions}. The next_call is a proc
    #   itself that accepts the options and returns a value. This run_context proc should return the result of the
    #   next_call.
    def initialize(
      name:,
      data_converter: nil,
      client_interceptors: nil,
      activities: nil,
      workflows: nil,
      worker_interceptors: nil,
      workflow_failure_exception_types: nil,
      run_context: nil
    )
      @options = Options.new(
        name:,
        data_converter:,
        client_interceptors:,
        activities:,
        workflows:,
        worker_interceptors:,
        workflow_failure_exception_types:,
        run_context:
      ).freeze
    end

    # Implements {Client::Plugin#name} and {Worker::Plugin#name}.
    def name
      @options.name
    end

    # Implements {Client::Plugin#configure_client}.
    def configure_client(options)
      if (data_converter = _single_option(new: @options.data_converter, existing: options.data_converter,
                                          type: Converters::DataConverter, name: 'data converter'))
        options = options.with(data_converter:)
      end
      if (interceptors = _array_option(new: @options.client_interceptors, existing: options.interceptors,
                                       name: 'client interceptor'))
        options = options.with(interceptors:)
      end
      options
    end

    # Implements {Client::Plugin#connect_client}.
    def connect_client(options, next_call)
      next_call.call(options)
    end

    # Implements {Worker::Plugin#configure_worker}.
    def configure_worker(options)
      if (activities = _array_option(new: @options.activities, existing: options.activities, name: 'activity'))
        options = options.with(activities:)
      end
      if (workflows = _array_option(new: @options.workflows, existing: options.workflows, name: 'workflow'))
        options = options.with(workflows:)
      end
      if (interceptors = _array_option(new: @options.worker_interceptors, existing: options.interceptors,
                                       name: 'worker interceptor'))
        options = options.with(interceptors:)
      end
      if (workflow_failure_exception_types = _array_option(new: @options.workflow_failure_exception_types,
                                                           existing: options.workflow_failure_exception_types,
                                                           name: 'workflow failure exception types'))
        options = options.with(workflow_failure_exception_types:)
      end
      options
    end

    # Implements {Worker::Plugin#run_worker}.
    def run_worker(options, next_call)
      if @options.run_context
        @options.run_context.call(options, next_call) # steep:ignore
      else
        next_call.call(options)
      end
    end

    # Implements {Worker::Plugin#configure_workflow_replayer}.
    def configure_workflow_replayer(options)
      if (data_converter = _single_option(new: @options.data_converter, existing: options.data_converter,
                                          type: Converters::DataConverter, name: 'data converter'))
        options = options.with(data_converter:)
      end
      if (workflows = _array_option(new: @options.workflows, existing: options.workflows, name: 'workflow'))
        options = options.with(workflows:)
      end
      if (interceptors = _array_option(new: @options.worker_interceptors, existing: options.interceptors,
                                       name: 'worker interceptor'))
        options = options.with(interceptors:)
      end
      if (workflow_failure_exception_types = _array_option(new: @options.workflow_failure_exception_types,
                                                           existing: options.workflow_failure_exception_types,
                                                           name: 'workflow failure exception types'))
        options = options.with(workflow_failure_exception_types:)
      end
      options
    end

    # Implements {Worker::Plugin#with_workflow_replay_worker}.
    def with_workflow_replay_worker(options, next_call)
      if @options.run_context
        @options.run_context.call(options, next_call) # steep:ignore
      else
        next_call.call(options)
      end
    end

    # @!visibility private
    def _single_option(new:, existing:, type:, name:)
      case new
      when nil
        nil
      when Proc
        new.call(existing).tap do |val|
          raise "Instance of #{name} required" unless val.is_a?(type)
        end
      when type
        new
      else
        raise "Unrecognized #{name} type #{new.class}"
      end
    end

    # @!visibility private
    def _array_option(new:, existing:, name:)
      case new
      when nil
        nil
      when Proc
        new.call(existing).tap do |conv|
          raise "Array for #{name} required" unless conv.is_a?(Array)
        end
      when Array
        existing + new # steep:ignore
      else
        raise "Unrecognized #{name} type #{new.class}"
      end
    end
  end
end
