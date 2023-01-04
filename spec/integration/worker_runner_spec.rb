# rubocop:disable Style/GlobalVars
require 'support/helpers/test_rpc'
require 'temporalio/activity'
require 'temporalio/client'
require 'temporalio/connection'
require 'temporalio/worker'
require 'temporalio/worker/runner'

# WARNING: This test is using a global queue to avoid timing of an activity start.
#          It allows us to test worker shutdown down right after activities got started.
$activity_start_queue = Queue.new

class TestWorkerIntegrationActivity < Temporalio::Activity
  def execute(num)
    $activity_start_queue << "started #{num}"
    sleep 0.2
    num.to_s
  end
end

describe Temporalio::Worker::Runner do
  support_path = 'spec/support'.freeze
  port = 5555
  task_queue = 'test-worker'.freeze
  namespace = 'ruby-samples'.freeze
  url = "localhost:#{port}".freeze

  subject { Temporalio::Worker::Runner.new(worker_1, worker_2) }
  let(:worker_1) do
    Temporalio::Worker.new(
      connection,
      namespace,
      activity_task_queue_1,
      activities: [TestWorkerIntegrationActivity],
      graceful_shutdown_timeout: graceful_timeout,
    )
  end
  let(:worker_2) do
    Temporalio::Worker.new(
      connection,
      namespace,
      activity_task_queue_2,
      activities: [TestWorkerIntegrationActivity],
      graceful_shutdown_timeout: graceful_timeout,
    )
  end
  let(:activity_task_queue_1) { 'test-activity-worker-1' }
  let(:activity_task_queue_2) { 'test-activity-worker-2' }
  let(:client) { Temporalio::Client.new(connection, namespace) }
  let(:connection) { Temporalio::Connection.new(url) }
  let(:graceful_timeout) { nil }
  let(:workflow) { 'kitchen_sink' }
  let(:input_1) do
    {
      actions: [{
        execute_activity: {
          name: 'TestWorkerIntegrationActivity',
          task_queue: activity_task_queue_1,
          args: [1],
        },
      }],
    }
  end
  let(:input_2) do
    {
      actions: [{
        execute_activity: {
          name: 'TestWorkerIntegrationActivity',
          task_queue: activity_task_queue_2,
          args: [2],
        },
      }],
    }
  end
  let(:start) { Queue.new }

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

  describe 'lifecycle' do
    after { $activity_start_queue.clear }

    it 'runs workers and shuts them down when finished' do
      handle_1 = client.start_workflow(workflow, input_1, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(workflow, input_2, id: SecureRandom.uuid, task_queue: task_queue)

      subject.run { handle_1.result && handle_2.result }

      expect(handle_1.result).to eq('1')
      expect(handle_2.result).to eq('2')
    end

    it 'stops when the block raises and waits for all the tasks to finish' do
      handle_1 = client.start_workflow(workflow, input_1, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(workflow, input_2, id: SecureRandom.uuid, task_queue: task_queue)

      expect do
        subject.run do
          $activity_start_queue.pop
          $activity_start_queue.pop
          raise 'test error'
        end
      end.to raise_error('test error')

      expect(handle_1.result).to eq('1')
      expect(handle_2.result).to eq('2')
    end

    it 'stops on explicit runner shutdown it waits for all the tasks to finish' do
      handle_1 = client.start_workflow(workflow, input_1, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(workflow, input_2, id: SecureRandom.uuid, task_queue: task_queue)

      Thread.new do
        $activity_start_queue.pop
        $activity_start_queue.pop
        subject.shutdown
      end

      subject.run

      expect(handle_1.result).to eq('1')
      expect(handle_2.result).to eq('2')
    end

    it 'stops on explicit runner error it waits for all the tasks to finish' do
      handle_1 = client.start_workflow(workflow, input_1, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(workflow, input_2, id: SecureRandom.uuid, task_queue: task_queue)

      Thread.new do
        $activity_start_queue.pop
        $activity_start_queue.pop
        subject.shutdown('runner test error')
      end

      expect { subject.run }.to raise_error('runner test error')

      expect(handle_1.result).to eq('1')
      expect(handle_2.result).to eq('2')
    end

    it 'stops on a single worker shutdown it waits for all the tasks to finish' do
      handle_1 = client.start_workflow(workflow, input_1, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(workflow, input_2, id: SecureRandom.uuid, task_queue: task_queue)

      Thread.new do
        $activity_start_queue.pop
        $activity_start_queue.pop
        worker_2.shutdown
      end

      subject.run

      expect(handle_1.result).to eq('1')
      expect(handle_2.result).to eq('2')
    end

    it 'stops on a single worker error it waits for all the tasks to finish' do
      handle_1 = client.start_workflow(workflow, input_1, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(workflow, input_2, id: SecureRandom.uuid, task_queue: task_queue)

      Thread.new do
        $activity_start_queue.pop
        $activity_start_queue.pop
        worker_2.shutdown('worker 2 test error')
      end

      expect { subject.run }.to raise_error('worker 2 test error')

      expect(handle_1.result).to eq('1')
      expect(handle_2.result).to eq('2')
    end

    it 'stops when a specified signal is received and waits for all the tasks to finish' do
      handle_1 = client.start_workflow(workflow, input_1, id: SecureRandom.uuid, task_queue: task_queue)
      handle_2 = client.start_workflow(workflow, input_2, id: SecureRandom.uuid, task_queue: task_queue)

      Thread.new do
        $activity_start_queue.pop
        $activity_start_queue.pop
        Process.kill('USR2', Process.pid)
      end

      Temporalio::Worker.run(worker_1, worker_2, stop_on_signal: %w[USR2])

      expect(handle_1.result).to eq('1')
      expect(handle_2.result).to eq('2')
    end

    context 'when graceful_shutdown_timeout is provided' do
      let(:graceful_timeout) { 0 }

      it 'cancels running activities' do
        handle_1 = client.start_workflow(workflow, input_1, id: SecureRandom.uuid, task_queue: task_queue)
        handle_2 = client.start_workflow(workflow, input_2, id: SecureRandom.uuid, task_queue: task_queue)

        Thread.new do
          $activity_start_queue.pop
          $activity_start_queue.pop
          subject.shutdown
        end

        subject.run

        expect { handle_1.result }.to raise_error do |error|
          expect(error).to be_a(Temporalio::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporalio::Error::ActivityError)
          expect(error.cause.message).to eq('activity error')
        end
        expect { handle_2.result }.to raise_error do |error|
          expect(error).to be_a(Temporalio::Error::WorkflowFailure)
          expect(error.cause).to be_a(Temporalio::Error::ActivityError)
          expect(error.cause.message).to eq('activity error')
        end
      end
    end
  end
end
# rubocop:enable Style/GlobalVars
