# frozen_string_literal: true

require 'base64_codec'
require 'securerandom'
require 'temporalio/client'
require 'temporalio/converters/data_converter'
require 'temporalio/testing'
require 'temporalio/worker'
require 'temporalio/worker/workflow_replayer'
require 'temporalio/workflow'
require 'test'

class WorkerWorkflowActivityTest < Test
  class SimpleActivity < Temporalio::Activity::Definition
    def execute(value)
      "from activity: #{value}"
    end
  end

  class SimpleWorkflow < Temporalio::Workflow::Definition
    def execute(scenario)
      case scenario.to_sym
      when :remote
        Temporalio::Workflow.execute_activity(SimpleActivity, 'remote', start_to_close_timeout: 10)
      when :remote_symbol_name
        Temporalio::Workflow.execute_activity(:SimpleActivity, 'remote', start_to_close_timeout: 10)
      when :remote_string_name
        Temporalio::Workflow.execute_activity('SimpleActivity', 'remote', start_to_close_timeout: 10)
      when :local
        Temporalio::Workflow.execute_local_activity(SimpleActivity, 'local', start_to_close_timeout: 10)
      when :local_symbol_name
        Temporalio::Workflow.execute_local_activity(:SimpleActivity, 'local', start_to_close_timeout: 10)
      when :local_string_name
        Temporalio::Workflow.execute_local_activity('SimpleActivity', 'local', start_to_close_timeout: 10)
      when :remote_with_summary
        Temporalio::Workflow.execute_activity(SimpleActivity, 'remote',
                                              start_to_close_timeout: 10, summary: 'remote summary')
      when :local_with_summary
        Temporalio::Workflow.execute_local_activity(SimpleActivity, 'local',
                                                    start_to_close_timeout: 10, summary: 'local summary')
      else
        raise NotImplementedError
      end
    end
  end

  class HeadersActivity < Temporalio::Activity::Definition
    def execute
      Temporalio::Activity::Context.current.info.headers
    end
  end

  class HeadersInboundInterceptor
    include Temporalio::Worker::Interceptor::Activity

    attr_reader :observations, :init_observations

    def initialize
      @observations = Queue.new
      @init_observations = Queue.new
    end

    def intercept_activity(next_interceptor)
      Inbound.new(self, next_interceptor)
    end

    class Inbound < Temporalio::Worker::Interceptor::Activity::Inbound
      def initialize(root, next_interceptor)
        super(next_interceptor)
        @root = root
      end

      def init(outbound)
        @root.init_observations << Temporalio::Activity::Context.current.info.headers.dup
        super
      end

      def execute(input)
        info = Temporalio::Activity::Context.current.info
        @root.observations << [input.headers, info.headers, info.attempt]
        super
      end
    end
  end

  class HeadersInboundMutationInterceptor
    include Temporalio::Worker::Interceptor::Activity

    def initialize(replace:)
      @replace = replace
    end

    def intercept_activity(next_interceptor)
      Inbound.new(@replace, next_interceptor)
    end

    class Inbound < Temporalio::Worker::Interceptor::Activity::Inbound
      def initialize(replace, next_interceptor)
        super(next_interceptor)
        @replace = replace
      end

      def execute(input)
        if @replace
          super(input.with(headers: { 'replacement' => 'replacement' }))
        else
          input.headers['in-place'] = 'mutated'
          super
        end
      end
    end
  end

  class HeadersInputObserverInterceptor
    include Temporalio::Worker::Interceptor::Activity

    attr_reader :observations

    def initialize
      @observations = Queue.new
    end

    def intercept_activity(next_interceptor)
      Inbound.new(self, next_interceptor)
    end

    class Inbound < Temporalio::Worker::Interceptor::Activity::Inbound
      def initialize(root, next_interceptor)
        super(next_interceptor)
        @root = root
      end

      def execute(input)
        @root.observations << [input.headers, Temporalio::Activity::Context.current.info.headers]
        super
      end
    end
  end

  class HeadersOutboundInterceptor
    include Temporalio::Worker::Interceptor::Workflow

    def intercept_workflow(next_interceptor)
      Inbound.new(next_interceptor)
    end

    class Inbound < Temporalio::Worker::Interceptor::Workflow::Inbound
      def init(outbound)
        super(Outbound.new(outbound))
      end
    end

    class Outbound < Temporalio::Worker::Interceptor::Workflow::Outbound
      def execute_activity(input)
        headers = input.headers.merge('interceptor-added' => 'added', 'request-id' => 'interceptor')
        super(input.with(headers:))
      end

      def execute_local_activity(input)
        headers = input.headers.merge('interceptor-added' => 'added', 'request-id' => 'interceptor')
        super(input.with(headers:))
      end
    end
  end

  class RetryingHeadersActivity < Temporalio::Activity::Definition
    def execute
      info = Temporalio::Activity::Context.current.info
      raise 'Intentional retry' if info.attempt == 1

      info.headers
    end
  end

  class RetryHeadersWorkflow < Temporalio::Workflow::Definition
    def execute(local)
      headers = { 'request-id' => 'req-retry', 'tenant' => { 'id' => 42 }, 'optional' => nil }
      retry_policy = Temporalio::RetryPolicy.new(initial_interval: 0.2, backoff_coefficient: 1)
      if local
        Temporalio::Workflow.execute_local_activity(
          RetryingHeadersActivity,
          schedule_to_close_timeout: 30,
          local_retry_threshold: 0.1,
          retry_policy:,
          headers:
        )
      else
        Temporalio::Workflow.execute_activity(
          RetryingHeadersActivity,
          schedule_to_close_timeout: 30,
          retry_policy:,
          headers:
        )
      end
    end
  end

  class HeadersWorkflow < Temporalio::Workflow::Definition
    def execute(scenario)
      case scenario.to_sym
      when :remote
        Temporalio::Workflow.execute_activity(
          HeadersActivity,
          start_to_close_timeout: 10,
          headers: { 'request-id' => 'req-workflow', 'tenant' => { 'id' => 42 }, 'optional' => nil }
        )
      when :local
        Temporalio::Workflow.execute_local_activity(
          HeadersActivity,
          start_to_close_timeout: 10,
          headers: { 'request-id' => 'req-workflow', 'tenant' => { 'id' => 42 }, 'optional' => nil }
        )
      when :remote_omitted
        Temporalio::Workflow.execute_activity(HeadersActivity, start_to_close_timeout: 10)
      when :local_omitted
        Temporalio::Workflow.execute_local_activity(HeadersActivity, start_to_close_timeout: 10)
      when :remote_empty
        Temporalio::Workflow.execute_activity(HeadersActivity, start_to_close_timeout: 10, headers: {})
      when :local_empty
        Temporalio::Workflow.execute_local_activity(HeadersActivity, start_to_close_timeout: 10, headers: {})
      else
        raise NotImplementedError
      end
    end
  end

  def test_simple
    assert_equal 'from activity: remote',
                 execute_workflow(SimpleWorkflow, :remote, activities: [SimpleActivity])
    assert_equal 'from activity: remote',
                 execute_workflow(SimpleWorkflow, :remote_symbol_name, activities: [SimpleActivity])
    assert_equal 'from activity: remote',
                 execute_workflow(SimpleWorkflow, :remote_string_name, activities: [SimpleActivity])
    assert_equal 'from activity: local',
                 execute_workflow(SimpleWorkflow, :local, activities: [SimpleActivity])
    assert_equal 'from activity: local',
                 execute_workflow(SimpleWorkflow, :local_symbol_name, activities: [SimpleActivity])
    assert_equal 'from activity: local',
                 execute_workflow(SimpleWorkflow, :local_string_name, activities: [SimpleActivity])
  end

  def test_activity_headers_remote_and_local
    expected = { 'request-id' => 'req-workflow', 'tenant' => { 'id' => 42 }, 'optional' => nil }
    %i[remote local].each do |scenario|
      interceptor = HeadersInboundInterceptor.new
      result = execute_workflow(
        HeadersWorkflow, scenario, activities: [HeadersActivity], interceptors: [interceptor]
      )
      assert_equal expected, result
      observation = interceptor.observations.pop
      assert_equal expected, observation[0]
      assert_equal expected, observation[1]
      assert_equal expected, interceptor.init_observations.pop
    end
  end

  def test_activity_headers_omitted_and_empty
    %i[remote_omitted local_omitted remote_empty local_empty].each do |scenario|
      interceptor = HeadersInboundInterceptor.new
      result = execute_workflow(
        HeadersWorkflow, scenario, activities: [HeadersActivity], interceptors: [interceptor]
      )
      assert_equal({}, result)
      observation = interceptor.observations.pop
      assert_equal({}, observation[0])
      assert_equal({}, observation[1])
      assert_equal({}, interceptor.init_observations.pop)
    end
  end

  def test_activity_headers_outbound_interception
    expected = {
      'request-id' => 'interceptor',
      'tenant' => { 'id' => 42 },
      'optional' => nil,
      'interceptor-added' => 'added'
    }
    %i[remote local].each do |scenario|
      interceptor = HeadersInboundInterceptor.new
      result = execute_workflow(
        HeadersWorkflow,
        scenario,
        activities: [HeadersActivity],
        interceptors: [interceptor, HeadersOutboundInterceptor.new]
      )
      assert_equal expected, result
      observation = interceptor.observations.pop
      assert_equal expected, observation[0]
      assert_equal expected, observation[1]
      assert_equal expected, interceptor.init_observations.pop
    end

    omitted_expected = { 'request-id' => 'interceptor', 'interceptor-added' => 'added' }
    %i[remote_omitted local_omitted].each do |scenario|
      interceptor = HeadersInboundInterceptor.new
      result = execute_workflow(
        HeadersWorkflow,
        scenario,
        activities: [HeadersActivity],
        interceptors: [interceptor, HeadersOutboundInterceptor.new]
      )
      assert_equal omitted_expected, result
      observation = interceptor.observations.pop
      assert_equal omitted_expected, observation[0]
      assert_equal omitted_expected, observation[1]
      assert_equal omitted_expected, interceptor.init_observations.pop
    end
  end

  def test_activity_headers_with_codec
    data_converter = Temporalio::Converters::DataConverter.new(payload_codec: Base64Codec.new)
    client = Temporalio::Client.new(**env.client.options.with(data_converter:).to_h)
    expected = { 'request-id' => 'req-workflow', 'tenant' => { 'id' => 42 }, 'optional' => nil }
    %i[remote local].each do |scenario|
      interceptor = HeadersInboundInterceptor.new
      result = execute_workflow(
        HeadersWorkflow,
        scenario,
        activities: [HeadersActivity],
        client:,
        workflow_payload_codec_thread_pool: Temporalio::Worker::ThreadPool.default,
        interceptors: [interceptor]
      )
      assert_equal expected, result
      observation = interceptor.observations.pop
      assert_equal expected, observation[0]
      assert_equal expected, observation[1]
      assert_equal expected, interceptor.init_observations.pop
    end
  end

  def test_activity_headers_retry_delivery
    expected = { 'request-id' => 'req-retry', 'tenant' => { 'id' => 42 }, 'optional' => nil }
    [false, true].each do |local|
      interceptor = HeadersInboundInterceptor.new
      history_events = execute_workflow(
        RetryHeadersWorkflow, local, activities: [RetryingHeadersActivity], interceptors: [interceptor]
      ) do |handle|
        assert_equal expected, handle.result
        handle.fetch_history_events.to_a
      end

      attempts = 2.times.map { interceptor.observations.pop }
      assert_equal [1, 2], attempts.map(&:last)
      assert_equal [expected, expected], attempts.map(&:first)
      assert_equal([expected, expected], attempts.map { |observation| observation[1] })
      assert_equal([expected, expected], 2.times.map { interceptor.init_observations.pop })
      next unless local

      assert_equal(1, history_events.count do |event|
        event.timer_started_event_attributes&.start_to_fire_timeout&.to_f == 0.2 # rubocop:disable Lint/FloatComparison
      end)
    end
  end

  def test_activity_headers_inbound_mutation_and_replacement
    received = { 'request-id' => 'req-workflow', 'tenant' => { 'id' => 42 }, 'optional' => nil }
    %i[remote local].each do |scenario|
      [false, true].each do |replace|
        observer = HeadersInputObserverInterceptor.new
        result = execute_workflow(
          HeadersWorkflow,
          scenario,
          activities: [HeadersActivity],
          interceptors: [HeadersInboundMutationInterceptor.new(replace:), observer]
        )
        downstream_headers, info_headers = observer.observations.pop
        if replace
          assert_equal received, result
          assert_equal received, info_headers
          assert_equal({ 'replacement' => 'replacement' }, downstream_headers)
        else
          expected = received.merge('in-place' => 'mutated')
          assert_equal expected, result
          assert_equal expected, info_headers
          assert_equal expected, downstream_headers
        end
      end
    end
  end

  def test_activity_headers_replay
    expected = { 'request-id' => 'req-workflow', 'tenant' => { 'id' => 42 }, 'optional' => nil }
    %i[remote local remote_omitted local_omitted].each do |scenario|
      history = execute_workflow(
        HeadersWorkflow, scenario, activities: [HeadersActivity]
      ) do |handle|
        assert_equal(scenario.to_s.end_with?('omitted') ? {} : expected, handle.result)
        handle.fetch_history
      end
      replay_result = Temporalio::Worker::WorkflowReplayer.new(workflows: [HeadersWorkflow]).replay_workflow(history)
      assert_nil replay_result.replay_failure
    end
  end

  class GoNoResultActivityWorkflow < Temporalio::Workflow::Definition
    def execute(activity_task_queue)
      Temporalio::Workflow.execute_activity(
        'no_result_activity',
        task_queue: activity_task_queue,
        start_to_close_timeout: 10
      )
    end
  end

  exclude_from_cloud :needs_cloud_adaptation,
                     'The Go kitchen-sink worker does not receive Cloud TLS configuration.'
  def test_activity_without_result_from_go_sdk
    env.with_kitchen_sink_worker do |activity_task_queue|
      execute_workflow(GoNoResultActivityWorkflow, activity_task_queue) do |handle|
        assert_nil assert_eventually_complete(handle:)
      end
    end
  end

  class FailureActivity < Temporalio::Activity::Definition
    def execute
      raise Temporalio::Error::ApplicationError.new('Intentional error', 'detail1', 'detail2', non_retryable: true)
    end
  end

  class FailureWorkflow < Temporalio::Workflow::Definition
    def execute(local)
      if local
        Temporalio::Workflow.execute_local_activity(FailureActivity, start_to_close_timeout: 10)
      else
        Temporalio::Workflow.execute_activity(FailureActivity, start_to_close_timeout: 10)
      end
    end
  end

  def test_failure
    # Most activity failure testing is already part of activity tests, this is just for checking it's propagated

    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(FailureWorkflow, false, activities: [FailureActivity])
    end
    assert_instance_of Temporalio::Error::ActivityError, err.cause
    assert_instance_of Temporalio::Error::ApplicationError, err.cause.cause
    assert_equal %w[detail1 detail2], err.cause.cause.details

    err = assert_raises(Temporalio::Error::WorkflowFailedError) do
      execute_workflow(FailureWorkflow, true, activities: [FailureActivity])
    end
    assert_instance_of Temporalio::Error::ApplicationError, err.cause
    assert_equal %w[detail1 detail2], err.cause.details
  end

  class CancellationSleepActivity < Temporalio::Activity::Definition
    def execute(amount)
      sleep(amount)
    end
  end

  class CancellationActivity < Temporalio::Activity::Definition
    attr_reader :started, :done

    def initialize
      # Can't use queue because we need to heartbeat during pop and timeout is not in Ruby 3.1
      @force_complete = false
      @force_complete_mutex = Mutex.new
    end

    def execute
      @started = true
      # Heartbeat every 100ms
      loop do
        Temporalio::Activity::Context.current.heartbeat
        # Check or sleep-then-loop
        val = @force_complete_mutex.synchronize { @force_complete }
        if val
          @done = :success
          return val
        end
        sleep(0.1)
      end
    rescue Temporalio::Error::CanceledError
      @done ||= :canceled
      sleep(0.1)
      'cancel swallowed'
    ensure
      @done ||= :failure # rubocop:disable Naming/MemoizedInstanceVariableName
    end

    def force_complete(value)
      @force_complete_mutex.synchronize { @force_complete = value }
    end
  end

  class CancellationWorkflow < Temporalio::Workflow::Definition
    def execute
      Temporalio::Workflow.wait_condition { false }
    end

    workflow_update
    def run(scenario, local)
      cancellation_type = case scenario.to_sym
                          when :try_cancel
                            Temporalio::Workflow::ActivityCancellationType::TRY_CANCEL
                          when :wait_cancel
                            Temporalio::Workflow::ActivityCancellationType::WAIT_CANCELLATION_COMPLETED
                          when :abandon
                            Temporalio::Workflow::ActivityCancellationType::ABANDON
                          else
                            raise NotImplementedError
                          end
      # Start
      cancellation, cancel_proc = Temporalio::Cancellation.new
      fut = Temporalio::Workflow::Future.new do
        if local
          Temporalio::Workflow.execute_local_activity(CancellationActivity,
                                                      schedule_to_close_timeout: 10,
                                                      cancellation:,
                                                      cancellation_type:)
        else
          Temporalio::Workflow.execute_activity(CancellationActivity,
                                                schedule_to_close_timeout: 10,
                                                heartbeat_timeout: 5,
                                                cancellation:,
                                                cancellation_type:)
        end
      end

      # Wait a bit then cancel
      if local
        Temporalio::Workflow.execute_local_activity(CancellationSleepActivity, 0.1,
                                                    schedule_to_close_timeout: 10)
      else
        Temporalio::Workflow.sleep(0.1)
      end
      cancel_proc.call

      fut.wait
    end
  end

  def test_cancellation
    [true, false].each do |local|
      # Try cancel
      # TODO(cretz): This is not working for local because worker shutdown hangs when local activity completes after
      # shutdown started
      unless local
        act = CancellationActivity.new
        execute_workflow(CancellationWorkflow, activities: [act, CancellationSleepActivity],
                                               max_heartbeat_throttle_interval: 0.2,
                                               task_timeout: 3) do |handle|
          update_handle = handle.start_update(
            CancellationWorkflow.run, :try_cancel, local,
            wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
          )
          err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) { update_handle.result }
          assert_instance_of Temporalio::Error::ActivityError, err.cause
          assert_instance_of Temporalio::Error::CanceledError, err.cause.cause
          assert_eventually { assert_equal :canceled, act.done }
        end
      end

      # Wait cancel
      act = CancellationActivity.new
      execute_workflow(CancellationWorkflow, activities: [act, CancellationSleepActivity],
                                             max_heartbeat_throttle_interval: 0.2,
                                             task_timeout: 3) do |handle|
        update_handle = handle.start_update(
          CancellationWorkflow.run, :wait_cancel, local,
          wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
        )
        # assert_eventually { assert act.started }
        # handle.signal(CancellationWorkflow.cancel)
        assert_equal 'cancel swallowed', update_handle.result
        assert_equal :canceled, act.done
      end

      # Abandon cancel
      act = CancellationActivity.new
      execute_workflow(CancellationWorkflow, activities: [act, CancellationSleepActivity],
                                             max_heartbeat_throttle_interval: 0.2,
                                             task_timeout: 3) do |handle|
        update_handle = handle.start_update(
          CancellationWorkflow.run, :abandon, local,
          wait_for_stage: Temporalio::Client::WorkflowUpdateWaitStage::ACCEPTED
        )
        # assert_eventually { assert act.started }
        # handle.signal(CancellationWorkflow.cancel)
        err = assert_raises(Temporalio::Error::WorkflowUpdateFailedError) { update_handle.result }
        assert_instance_of Temporalio::Error::ActivityError, err.cause
        assert_instance_of Temporalio::Error::CanceledError, err.cause.cause
        assert_nil act.done
        sleep(0.2)
        act.force_complete 'manually complete'
        assert_eventually { assert_equal :success, act.done }
      end
    end
  end

  class LocalBackoffActivity < Temporalio::Activity::Definition
    def execute
      # Succeed on the third attempt
      return 'done' if Temporalio::Activity::Context.current.info.attempt == 3

      raise 'Intentional failure'
    end
  end

  class LocalBackoffWorkflow < Temporalio::Workflow::Definition
    def execute
      # Give a fixed retry of every 200ms, but with a local threshold of 100ms
      Temporalio::Workflow.execute_local_activity(
        LocalBackoffActivity,
        schedule_to_close_timeout: 30,
        local_retry_threshold: 0.1,
        retry_policy: Temporalio::RetryPolicy.new(initial_interval: 0.2, backoff_coefficient: 1)
      )
    end
  end

  def test_local_backoff
    execute_workflow(LocalBackoffWorkflow, activities: [LocalBackoffActivity]) do |handle|
      assert_equal 'done', handle.result
      # Make sure there were two 200ms timers
      assert_equal(2, handle.fetch_history_events.count do |e|
        e.timer_started_event_attributes&.start_to_fire_timeout&.to_f == 0.2 # rubocop:disable Lint/FloatComparison
      end)
    end
  end

  class CancellationDetailsActivity < Temporalio::Activity::Definition
    def initialize(queue)
      @queue = queue
    end

    def execute(swallow)
      @queue << Temporalio::Activity::Context.current.info.activity_id
      loop do
        Temporalio::Activity::Context.current.heartbeat
        sleep(0.1)
      end
    rescue Temporalio::Error::CanceledError
      Temporalio::Activity::Context.current.heartbeat('final-heartbeat')
      # Reraise if not catching
      raise unless swallow

      det = Temporalio::Activity::Context.current.cancellation_details
      "canceled - paused: #{det&.paused?}, requested: #{det&.cancel_requested?}, reset: #{det&.reset?}"
    end
  end

  class CancellationDetailsWorkflow < Temporalio::Workflow::Definition
    def execute(swallow)
      Temporalio::Workflow.execute_activity(
        CancellationDetailsActivity, swallow,
        start_to_close_timeout: 1000, heartbeat_timeout: 3
      )
    end
  end

  exclude_from_cloud :requires_cloud_provisioning,
                     'Requires Activity pause and reset APIs that are not enabled in Cloud CI.'
  def test_cancellation_pause
    # Swallow
    queue = Queue.new
    execute_workflow(
      CancellationDetailsWorkflow, true,
      activities: [CancellationDetailsActivity.new(queue)]
    ) do |handle|
      # Wait for activity to start
      activity_id = queue.pop(timeout: 10)
      assert activity_id
      # Send pause, and confirm we get what we expect
      req = Temporalio::Api::WorkflowService::V1::PauseActivityRequest.new(
        namespace: env.client.namespace,
        execution: Temporalio::Api::Common::V1::WorkflowExecution.new(
          workflow_id: handle.id,
          run_id: handle.result_run_id
        ),
        identity: env.client.connection.options.identity,
        id: activity_id,
        reason: 'my reason'
      )
      env.client.workflow_service.pause_activity(req)
      assert_equal 'canceled - paused: true, requested: false, reset: false', handle.result
    end

    # Re-raise
    queue = Queue.new
    execute_workflow(
      CancellationDetailsWorkflow, false,
      activities: [CancellationDetailsActivity.new(queue)]
    ) do |handle|
      # Wait for activity to start
      activity_id = queue.pop(timeout: 10)
      assert activity_id
      # Send pause, and confirm we get what we expect
      req = Temporalio::Api::WorkflowService::V1::PauseActivityRequest.new(
        namespace: env.client.namespace,
        execution: Temporalio::Api::Common::V1::WorkflowExecution.new(
          workflow_id: handle.id,
          run_id: handle.result_run_id
        ),
        identity: env.client.connection.options.identity,
        id: activity_id,
        reason: 'my reason'
      )
      env.client.workflow_service.pause_activity(req)
      assert_eventually do
        acts = handle.describe.raw_description.pending_activities
        assert acts.size == 1
        assert acts.first.paused
        assert_equal '"final-heartbeat"', acts.first.heartbeat_details&.payloads&.first&.data # rubocop:disable Style/SafeNavigationChainLength
      end
    end
  end

  exclude_from_cloud :requires_cloud_provisioning,
                     'Requires Activity pause and reset APIs that are not enabled in Cloud CI.'
  def test_cancellation_reset
    queue = Queue.new
    execute_workflow(
      CancellationDetailsWorkflow, true,
      activities: [CancellationDetailsActivity.new(queue)]
    ) do |handle|
      # Wait for activity to start
      activity_id = queue.pop(timeout: 10)
      assert activity_id
      # Send reset, and confirm we get what we expect
      req = Temporalio::Api::WorkflowService::V1::ResetActivityRequest.new(
        namespace: env.client.namespace,
        execution: Temporalio::Api::Common::V1::WorkflowExecution.new(
          workflow_id: handle.id,
          run_id: handle.result_run_id
        ),
        identity: env.client.connection.options.identity,
        id: activity_id
      )
      env.client.workflow_service.reset_activity(req)
      assert_equal 'canceled - paused: false, requested: false, reset: true', handle.result
    end
  end

  def test_activity_summary
    data_converter = Temporalio::Converters::DataConverter.default
    execute_workflow(SimpleWorkflow, :remote_with_summary, activities: [SimpleActivity]) do |handle|
      handle.result
      activity_events = handle.fetch_history.events
                              .select { |e| e.event_type == :EVENT_TYPE_ACTIVITY_TASK_SCHEDULED }
      assert_equal 1, activity_events.size
      assert_equal 'remote summary', data_converter.from_payload(activity_events.first.user_metadata.summary)
      assert_nil activity_events.first.user_metadata.details
    end
  end

  def test_local_activity_summary
    data_converter = Temporalio::Converters::DataConverter.default
    execute_workflow(SimpleWorkflow, :local_with_summary, activities: [SimpleActivity]) do |handle|
      handle.result
      print handle.fetch_history.events
      activity_events = handle.fetch_history.events.select do |e|
        e.event_type == :EVENT_TYPE_MARKER_RECORDED &&
          e.marker_recorded_event_attributes.marker_name == 'core_local_activity'
      end
      assert_equal 1, activity_events.size
      assert_equal 'local summary', data_converter.from_payload(activity_events.first.user_metadata.summary)
      assert_nil activity_events.first.user_metadata.details
    end
  end
end
