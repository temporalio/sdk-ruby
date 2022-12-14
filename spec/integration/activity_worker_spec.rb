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

# This activity will get interrupted by a Thread#raise
class TestCancellingActivity < Temporal::Activity
  def execute(cycles)
    cycles.times do
      sleep 0.2
      activity.heartbeat
    end
  end
end

# The shielded block will execute in full without interruption
class TestCancellingActivityWithShield < Temporal::Activity
  def execute(cycles)
    i = 0
    activity.shield do
      cycles.times do
        sleep 0.2
        activity.heartbeat
        i += 1
      end
    end
    i += 1 # this line will not get executed
  rescue Temporal::Error::CancelledError
    i.to_s # expected to eq '10'
  end
end

# Responding to cancellation by failing activity
class TestManuallyCancellingActivityWithShield < Temporal::Activity
  def execute(cycles)
    activity.shield do
      cycles.times do
        sleep 0.2
        activity.heartbeat
        raise 'Manually failed' if activity.cancelled?
      end
    end
  end
end

# A shielded activity will not get cancelled
class TestCancellingShieldedActivity < Temporal::Activity
  shielded!

  def execute(cycles)
    cycles.times do
      sleep 0.2
      activity.heartbeat
    end

    'completed'
  end
end

# Manually handling cancellation (while completing activity)
class TestCancellationIgnoringActivity < Temporal::Activity
  def execute(cycles)
    i = 0
    cycles.times do
      sleep 0.2
      activity.heartbeat
      i += 1
    end
  rescue Temporal::Error::CancelledError
    i.to_s # expected to be less than '10'
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
        TestCancellingActivity,
        TestCancellingActivityWithShield,
        TestManuallyCancellingActivityWithShield,
        TestCancellingShieldedActivity,
        TestCancellationIgnoringActivity,
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
      handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

      expect(handle.result).to eq('foo bar')
    end
  end

  describe 'activity cancellation' do
    let(:cycles) { 10 }
    let(:input) do
      {
        actions: [{
          execute_activity: {
            name: activity_name,
            task_queue: activity_task_queue,
            args: [cycles],
            cancel_after_ms: 100,
            wait_for_cancellation: true,
            heartbeat_timeout_ms: 1000,
          },
        }],
      }
    end

    context 'when unhandled' do
      let(:activity_name) { 'TestCancellingActivity' }

      it 'raises from within an activity' do
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect { handle.result }.to raise_error do |error|
          expect(error).to be_a(Temporal::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporal::Error::CancelledError)
        end
      end
    end

    context 'when protected by a shield' do
      let(:activity_name) { 'TestCancellingActivityWithShield' }

      it 'performs all cycles' do
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect(handle.result.to_i).to eq(cycles)
      end
    end

    context 'when handled manually in a shield' do
      let(:activity_name) { 'TestManuallyCancellingActivityWithShield' }

      it 'raises' do
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect { handle.result }.to raise_error do |error|
          expect(error).to be_a(Temporal::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporal::Error::ActivityError)
          expect(error.cause.cause).to be_a(Temporal::Error::ApplicationError)
          expect(error.cause.cause.message).to eq('Manually failed')
        end
      end
    end

    context 'when unhandled by a shielded activity' do
      let(:activity_name) { 'TestCancellingShieldedActivity' }

      it 'does not affect activity' do
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect(handle.result).to eq('completed')
      end
    end

    context 'when intentionally ignored' do
      let(:activity_name) { 'TestCancellationIgnoringActivity' }

      it 'return a number of performed cycles' do
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect(handle.result.to_i).to be < cycles
      end
    end
  end
end
