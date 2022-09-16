require 'json'
require 'securerandom'
require 'socket'
require 'temporal/errors'
require 'temporal/converter'
require 'temporal/client/workflow_handle'
require 'temporal/client/implementation'
require 'temporal/workflow/id_reuse_policy'

module Temporal
  class Client
    attr_reader :namespace

    # TODO: More argument to follow for converters, codecs, etc
    def initialize(connection, namespace, interceptors: [])
      @namespace = namespace
      converter = Converter.new
      @implementation = Client::Implementation.new(connection, namespace, converter, interceptors)
    end

    def start_workflow(
      workflow,
      *args,
      id:,
      task_queue:,
      execution_timeout: nil,
      run_timeout: nil,
      task_timeout: nil,
      id_reuse_policy: Workflow::IDReusePolicy::ALLOW_DUPLICATE,
      retry_policy: nil,
      cron_schedule: '',
      memo: nil,
      search_attributes: nil,
      headers: {},
      start_signal: nil,
      start_signal_args: []
    )
      input = Interceptor::Client::StartWorkflowInput.new(
        workflow: workflow,
        args: args,
        id: id,
        task_queue: task_queue,
        execution_timeout: execution_timeout,
        run_timeout: run_timeout,
        task_timeout: task_timeout,
        id_reuse_policy: id_reuse_policy,
        retry_policy: retry_policy,
        cron_schedule: cron_schedule,
        memo: memo,
        search_attributes: search_attributes,
        headers: headers,
        start_signal: start_signal,
        start_signal_args: start_signal_args,
      )

      implementation.start_workflow(input)
    end

    def workflow_handle(id, run_id: nil, first_execution_run_id: nil)
      WorkflowHandle.new(
        implementation,
        id,
        run_id: run_id,
        result_run_id: run_id,
        first_execution_run_id: first_execution_run_id,
      )
    end

    private

    attr_reader :implementation
  end
end
