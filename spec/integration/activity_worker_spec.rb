require 'support/helpers/test_rpc'
require 'temporal/activity'
require 'temporal/bridge'
require 'temporal/client'
require 'temporal/worker'

class TestBasicActivity < Temporal::Activity
  def execute(name)
    "Hello, #{name}!"
  end
end

class TestCustomNameActivity < Temporal::Activity
  activity_name 'test-activity'

  def execute(one, two)
    [one, two].join(', ')
  end
end

class TestBasicFailingActivity < Temporal::Activity
  def execute
    raise 'test error'
  end
end

class TestHeartbeatActivity < Temporal::Activity
  def execute
    if activity.info.heartbeat_details.empty?
      activity.heartbeat('foo', 'bar')
      raise 'retry'
    end

    activity.info.heartbeat_details.join(' ')
  end
end

describe Temporal::Worker::ActivityWorker do
  support_path = 'spec/support'.freeze
  port = 5555
  task_queue = 'test-worker'.freeze
  namespace = 'ruby-samples'.freeze
  url = "localhost:#{port}".freeze

  subject do
    Temporal::Worker.new(
      connection,
      namespace,
      activity_task_queue,
      activities: [
        TestBasicActivity,
        TestCustomNameActivity,
        TestBasicFailingActivity,
        TestHeartbeatActivity,
      ],
    )
  end

  let(:activity_task_queue) { 'test-activity-worker' }
  let(:client) { Temporal::Client.new(connection, namespace) }
  let(:connection) { Temporal::Connection.new(url) }
  let(:id) { SecureRandom.uuid }
  let(:workflow) { 'kitchen_sink' }

  before(:all) do
    Temporal::Bridge.init_telemetry

    @server_pid = fork { exec("#{support_path}/go_server/main #{port} #{namespace}") }
    Helpers::TestRPC.wait(url, 10, 0.5)

    @worker_pid = fork { exec("#{support_path}/go_worker/main #{url} #{namespace} #{task_queue}") }
  end

  after(:all) do
    Process.kill('INT', @worker_pid)
    Process.wait(@worker_pid)
    Process.kill('INT', @server_pid)
    Process.wait(@server_pid)
  end

  before { subject.start }
  after { subject.shutdown }

  describe 'running an activity' do
    # TODO: Use a different task queue due to an incomplete Worker#shutdown implementation
    let(:activity_task_queue) { 'test-activity-worker-1' }

    it 'runs an activity and returns a result' do
      input = {
        actions: [{
          execute_activity: {
            name: 'TestBasicActivity',
            task_queue: activity_task_queue,
            args: ['test'],
          },
        }],
      }
      handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

      expect(handle.result).to eq('Hello, test!')
    end

    context 'when activity has a custom name' do
      # TODO: Use a different task queue due to an incomplete Worker#shutdown implementation
      let(:activity_task_queue) { 'test-activity-worker-2' }

      it 'runs an activity and returns a result' do
        input = {
          actions: [{
            execute_activity: {
              name: 'test-activity',
              task_queue: activity_task_queue,
              args: %w[foo bar],
            },
          }],
        }
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect(handle.result).to eq('foo, bar')
      end
    end

    context 'when activity fails' do
      # TODO: Use a different task queue due to an incomplete Worker#shutdown implementation
      let(:activity_task_queue) { 'test-activity-worker-3' }

      it 'raises an application error' do
        input = {
          actions: [{
            execute_activity: {
              name: 'TestBasicFailingActivity',
              task_queue: activity_task_queue,
            },
          }],
        }
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect { handle.result }.to raise_error do |error|
          expect(error).to be_a(Temporal::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporal::Error::ActivityError)
          expect(error.cause.cause).to be_a(Temporal::Error::ApplicationError)
          expect(error.cause.cause.message).to eq('test error')
        end
      end
    end
  end

  describe 'running a heartbeating activity' do
    # TODO: Use a different task queue due to an incomplete Worker#shutdown implementation
    let(:activity_task_queue) { 'test-activity-worker-4' }

    it 'runs an activity and returns heartbeat details' do
      input = {
        actions: [{
          execute_activity: {
            name: 'TestHeartbeatActivity',
            task_queue: activity_task_queue,
            retry_max_attempts: 2,
          },
        }],
      }
      handle = client.start_workflow(
        workflow,
        input,
        id: id,
        task_queue: task_queue,
      )

      expect(handle.result).to eq('foo bar')
    end
  end
end
