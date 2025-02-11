# frozen_string_literal: true

require 'securerandom'
require 'temporalio/activity'
require 'temporalio/client'
require 'temporalio/testing/workflow_environment'
require 'temporalio/worker'
require 'temporalio/workflow'
require 'test'
require 'workflow_utils'

module Testing
  class WorkflowEnvironmentTest < Test
    include WorkflowUtils

    class SlowWorkflow < Temporalio::Workflow::Definition
      TWO_DAYS = 2 * 24 * 60 * 60

      def execute
        sleep(TWO_DAYS)
        'all done'
      end

      workflow_query
      def current_timestamp
        Temporalio::Workflow.now.to_i
      end

      workflow_signal
      def some_signal
        # Do nothing
      end
    end

    def test_time_skipping_auto
      skip_if_not_x86!
      Temporalio::Testing::WorkflowEnvironment.start_time_skipping(logger: Logger.new($stdout)) do |env|
        worker = Temporalio::Worker.new(
          client: env.client,
          task_queue: "tq-#{SecureRandom.uuid}",
          workflows: [SlowWorkflow]
        )
        worker.run do
          # Check that timestamp is around now
          assert_in_delta Time.now, env.current_time, 30.0

          # Run workflow
          assert_equal 'all done',
                       env.client.execute_workflow(SlowWorkflow,
                                                   id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue)

          # Check that timestamp is now about two days from now
          assert_in_delta Time.now + SlowWorkflow::TWO_DAYS, env.current_time, 30.0
        end
      end
    end

    def test_time_skipping_manual
      skip_if_not_x86!
      Temporalio::Testing::WorkflowEnvironment.start_time_skipping(logger: Logger.new($stdout)) do |env|
        worker = Temporalio::Worker.new(
          client: env.client,
          task_queue: "tq-#{SecureRandom.uuid}",
          workflows: [SlowWorkflow]
        )
        worker.run do
          # Start workflow
          handle = env.client.start_workflow(SlowWorkflow,
                                             id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue)

          # Send signal then check query is around now
          handle.signal(SlowWorkflow.some_signal)
          assert_in_delta Time.now, Time.at(handle.query(SlowWorkflow.current_timestamp)), 30.0 # steep:ignore

          # Sleep for two hours then signal then check query again
          two_hours = 2 * 60 * 60
          env.sleep(two_hours)
          handle.signal(SlowWorkflow.some_signal)
          assert_in_delta(
            Time.now + two_hours,
            Time.at(handle.query(SlowWorkflow.current_timestamp)), # steep:ignore
            30.0
          )
        end
      end
    end

    class HeartbeatTimeoutActivity < Temporalio::Activity::Definition
      def initialize(env)
        @env = env
      end

      def execute
        # Sleep for twice as long as heartbeat timeout
        timeout = Temporalio::Activity::Context.current.info.heartbeat_timeout or raise 'No timeout'
        @env.sleep(timeout * 2)
        'all done'
      end
    end

    class HeartbeatTimeoutWorkflow < Temporalio::Workflow::Definition
      def execute
        # Run activity with 20 second heartbeat timeout
        Temporalio::Workflow.execute_activity(
          HeartbeatTimeoutActivity,
          schedule_to_close_timeout: 1000,
          heartbeat_timeout: 20,
          retry_policy: Temporalio::RetryPolicy.new(max_attempts: 1)
        )
      end
    end

    def test_time_skipping_heartbeat_timeout
      skip_if_not_x86!
      Temporalio::Testing::WorkflowEnvironment.start_time_skipping(logger: Logger.new($stdout)) do |env|
        worker = Temporalio::Worker.new(
          client: env.client,
          task_queue: "tq-#{SecureRandom.uuid}",
          workflows: [HeartbeatTimeoutWorkflow],
          activities: [HeartbeatTimeoutActivity.new(env)]
        )
        worker.run do
          # Run workflow and confirm it got heartbeat timeout
          err = assert_raises(Temporalio::Error::WorkflowFailedError) do
            env.client.execute_workflow(HeartbeatTimeoutWorkflow,
                                        id: "wf-#{SecureRandom.uuid}", task_queue: worker.task_queue)
          end
          assert_instance_of Temporalio::Error::ActivityError, err.cause
          assert_instance_of Temporalio::Error::TimeoutError, err.cause.cause
          assert_equal Temporalio::Error::TimeoutError::TimeoutType::HEARTBEAT, err.cause.cause.type
        end
      end
    end

    def test_start_local_search_attributes
      pre = 'ruby-temporal-test-'
      attr_boolean = Temporalio::SearchAttributes::Key.new(
        "#{pre}boolean", Temporalio::SearchAttributes::IndexedValueType::BOOLEAN
      )
      attr_float = Temporalio::SearchAttributes::Key.new(
        "#{pre}float", Temporalio::SearchAttributes::IndexedValueType::FLOAT
      )
      attr_integer = Temporalio::SearchAttributes::Key.new(
        "#{pre}integer", Temporalio::SearchAttributes::IndexedValueType::INTEGER
      )
      attr_keyword = Temporalio::SearchAttributes::Key.new(
        "#{pre}keyword", Temporalio::SearchAttributes::IndexedValueType::KEYWORD
      )
      attr_keyword_list = Temporalio::SearchAttributes::Key.new(
        "#{pre}keyword-list", Temporalio::SearchAttributes::IndexedValueType::KEYWORD_LIST
      )
      attr_text = Temporalio::SearchAttributes::Key.new(
        "#{pre}text", Temporalio::SearchAttributes::IndexedValueType::TEXT
      )
      attr_time = Temporalio::SearchAttributes::Key.new(
        "#{pre}time", Temporalio::SearchAttributes::IndexedValueType::TIME
      )
      attrs = Temporalio::SearchAttributes.new(
        {
          attr_boolean => true,
          attr_float => 1.23,
          attr_integer => 456,
          attr_keyword => 'some keyword',
          attr_keyword_list => ['some keyword list 1', 'some keyword list 2'],
          attr_text => 'some text',
          attr_time => Time.at(Time.now.to_i)
        }
      )

      # Confirm when used in env without SAs it fails
      Temporalio::Testing::WorkflowEnvironment.start_local do |env|
        err = assert_raises(Temporalio::Error::RPCError) do
          env.client.start_workflow(
            :some_workflow,
            id: "wf-#{SecureRandom.uuid}", task_queue: "tq-#{SecureRandom.uuid}",
            search_attributes: attrs
          )
        end
        assert_includes err.message, 'no mapping defined'
      end

      # Confirm when used in env with SAs it succeeds
      Temporalio::Testing::WorkflowEnvironment.start_local(search_attributes: attrs.to_h.keys) do |env|
        handle = env.client.start_workflow(
          :some_workflow,
          id: "wf-#{SecureRandom.uuid}", task_queue: "tq-#{SecureRandom.uuid}",
          search_attributes: attrs
        )
        assert_equal attrs, handle.describe.search_attributes
      end
    end
  end
end
