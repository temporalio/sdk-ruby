require 'temporalio/activity'
require 'temporalio/bridge'
require 'temporalio/client'
require 'temporalio/worker'

class TestBasicActivity < Temporalio::Activity
  def execute(name)
    "Hello, #{name}!"
  end
end

class TestCustomNameActivity < Temporalio::Activity
  activity_name 'test-activity'

  def execute(one, two)
    [one, two].join(', ')
  end
end

class TestBasicFailingActivity < Temporalio::Activity
  def execute
    raise 'test error'
  end
end

class TestHeartbeatActivity < Temporalio::Activity
  def execute
    if activity.info.heartbeat_details.empty?
      activity.heartbeat('foo', 'bar')
      raise 'retry'
    end

    activity.info.heartbeat_details.join(' ')
  end
end

# This activity will get interrupted by a Thread#raise
class TestCancellingActivity < Temporalio::Activity
  def execute(cycles)
    cycles.times do
      sleep 0.2
      activity.heartbeat
    end
  end
end

# The shielded block will execute in full without interruption
class TestCancellingActivityWithShield < Temporalio::Activity
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
  rescue Temporalio::Error::ActivityCancelled
    i.to_s # expected to eq '10'
  end
end

# Responding to cancellation by failing activity
class TestManuallyCancellingActivityWithShield < Temporalio::Activity
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
class TestCancellingShieldedActivity < Temporalio::Activity
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
class TestCancellationIgnoringActivity < Temporalio::Activity
  def execute(cycles)
    i = 0
    cycles.times do
      sleep 0.2
      activity.heartbeat
      i += 1
    end
  rescue Temporalio::Error::ActivityCancelled
    i.to_s # expected to be less than '10'
  end
end

describe Temporalio::Worker::ActivityWorker do
  support_path = 'spec/support'.freeze
  port = 5555
  task_queue = 'test-worker'.freeze
  namespace = 'ruby-samples'.freeze
  url = "localhost:#{port}".freeze

  subject do
    Temporalio::Worker.new(
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
      interceptors: [interceptor],
    )
  end

  let(:activity_task_queue) { 'test-activity-worker' }
  let(:client) { Temporalio::Client.new(connection, namespace) }
  let(:connection) { Temporalio::Connection.new(url) }
  let(:id) { SecureRandom.uuid }
  let(:workflow) { 'kitchen_sink' }
  let(:interceptor) { Helpers::TestCaptureInterceptor.new }

  before(:all) do
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

      expect(subject.run { handle.result }).to eq('Hello, test!')
      expect(interceptor.called_methods).to eq(%i[execute_activity])
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

        expect(subject.run { handle.result }).to eq('foo, bar')
        expect(interceptor.called_methods).to eq(%i[execute_activity])
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

        expect do
          subject.run { handle.result }
        end.to raise_error do |error|
          expect(error).to be_a(Temporalio::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporalio::Error::ActivityError)
          expect(error.cause.cause).to be_a(Temporalio::Error::ApplicationError)
          expect(error.cause.cause.message).to eq('test error')
        end
        expect(interceptor.called_methods).to eq(%i[execute_activity])
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

      expect(subject.run { handle.result }).to eq('foo bar')
      # TestHeartbeatActivity calls info to access heartbeat_details and gets retried once
      expect(interceptor.called_methods).to eq(
        %i[execute_activity activity_info heartbeat execute_activity activity_info activity_info]
      )
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

        expect do
          subject.run { handle.result }
        end.to raise_error do |error|
          expect(error).to be_a(Temporalio::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporalio::Error::CancelledError)
        end
      end
    end

    context 'when protected by a shield' do
      let(:activity_name) { 'TestCancellingActivityWithShield' }

      it 'performs all cycles' do
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect(subject.run { handle.result }.to_i).to eq(cycles)
      end
    end

    context 'when handled manually in a shield' do
      let(:activity_name) { 'TestManuallyCancellingActivityWithShield' }

      it 'raises' do
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect do
          subject.run { handle.result }
        end.to raise_error do |error|
          expect(error).to be_a(Temporalio::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporalio::Error::ActivityError)
          expect(error.cause.cause).to be_a(Temporalio::Error::ApplicationError)
          expect(error.cause.cause.message).to eq('Manually failed')
        end
      end
    end

    context 'when unhandled by a shielded activity' do
      let(:activity_name) { 'TestCancellingShieldedActivity' }

      it 'does not affect activity' do
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect(subject.run { handle.result }).to eq('completed')
      end
    end

    context 'when intentionally ignored' do
      let(:activity_name) { 'TestCancellationIgnoringActivity' }

      it 'return a number of performed cycles' do
        handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

        expect(subject.run { handle.result }.to_i).to be < cycles
      end
    end
  end
end
