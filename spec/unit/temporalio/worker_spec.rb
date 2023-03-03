require 'support/helpers/test_rpc'
require 'temporalio/activity'
require 'temporalio/bridge'
require 'temporalio/connection'
require 'temporalio/worker'
require 'temporalio/worker/activity_worker'
require 'temporalio/worker/thread_pool_executor'

class TestActivity < Temporalio::Activity; end

describe Temporalio::Worker do
  subject { described_class.new(connection, namespace, task_queue, activities: activities) }
  let(:connection) { instance_double(Temporalio::Connection, core_connection: core_connection) }
  let(:core_connection) { instance_double(Temporalio::Bridge::Connection) }
  let(:core_worker) { instance_double(Temporalio::Bridge::Worker) }
  let(:namespace) { 'test-namespace' }
  let(:task_queue) { 'test-task-queue' }
  let(:activities) { [TestActivity] }
  let(:runner) { instance_double(Temporalio::Worker::Runner, run: nil) }

  before { allow(Temporalio::Bridge::Worker).to receive(:create).and_return(core_worker) }

  describe '.run' do
    let(:worker_one) { described_class.new(connection, namespace, task_queue, activities: activities) }
    let(:worker_two) { described_class.new(connection, namespace, task_queue, activities: activities) }

    before { allow(Temporalio::Worker::Runner).to receive(:new).and_return(runner) }

    it 'initializes a Runner and runs it' do
      run_block = -> {}

      described_class.run(worker_one, worker_two, &run_block)

      expect(Temporalio::Worker::Runner).to have_received(:new).with(worker_one, worker_two)
      expect(runner).to have_received(:run) do |&block|
        expect(block).to eq(run_block)
      end
    end

    context 'when shutdown_signals is provided' do
      it 'initializes a Runner and runs it' do
        described_class.run(worker_one, worker_two, shutdown_signals: %w[USR2])

        expect(Temporalio::Worker::Runner).to have_received(:new).with(worker_one, worker_two)
        expect(runner).to have_received(:run) do |&block|
          expect(block).to an_instance_of(Proc)
        end
      end
    end
  end

  describe '#initialize' do
    before do
      allow(Temporalio::Worker::ThreadPoolExecutor).to receive(:new).and_call_original
    end

    it 'initializes the core worker' do
      described_class.new(connection, namespace, task_queue, activities: activities)

      expect(Temporalio::Bridge::Worker)
        .to have_received(:create)
        .with(an_instance_of(Temporalio::Bridge::Runtime), core_connection, namespace, task_queue, 1_000, false)
    end

    it 'uses a default executor with a default size' do
      described_class.new(connection, namespace, task_queue, activities: activities)

      expect(Temporalio::Worker::ThreadPoolExecutor).to have_received(:new).with(100)
    end

    context 'without activities' do
      it 'raises an error' do
        expect do
          described_class.new(connection, namespace, task_queue)
        end.to raise_error(ArgumentError, 'At least one activity or workflow must be specified')
      end
    end

    context 'with max_concurrent_activities' do
      it 'uses a default executor with a specified size' do
        described_class.new(
          connection,
          namespace,
          task_queue,
          activities: activities,
          max_concurrent_activities: 42
        )

        expect(Temporalio::Worker::ThreadPoolExecutor).to have_received(:new).with(42)
      end
    end
  end

  describe '#run' do
    before { allow(Temporalio::Worker::Runner).to receive(:new).and_return(runner) }

    it 'initializes a Runner and runs it' do
      run_block = -> {}

      subject.run(&run_block)

      expect(Temporalio::Worker::Runner).to have_received(:new).with(subject)
      expect(runner).to have_received(:run) do |&block|
        expect(block).to eq(run_block)
      end
    end
  end

  describe '#start' do
    let(:queue) { Queue.new }
    let(:reactor) { Temporalio::Runtime.instance.reactor }

    before do
      allow(core_worker)
        .to receive(:poll_activity_task)
        .and_raise(Temporalio::Bridge::Error::WorkerShutdown)

      allow(core_worker).to receive(:initiate_shutdown)
      allow(core_worker).to receive(:finalize_shutdown)

      allow(reactor).to receive(:async).and_call_original
    end

    after { subject.shutdown } # wait for shutdown

    it 'runs the workers inside a shared reactor' do
      subject.start

      expect(subject).to be_started
      expect(subject).to be_running

      expect(reactor).to have_received(:async)
    end

    it 'raises when attempting to start twice' do
      subject.start

      expect { subject.start }.to raise_error('Worker is already started')
    end
  end

  describe '#shutdown' do
    let(:activity_executor) { Temporalio::Worker::ThreadPoolExecutor.new(1) }
    let(:activity_worker) { instance_double(Temporalio::Worker::ActivityWorker, drain: nil) }

    before do
      allow(core_worker).to receive(:initiate_shutdown)
      allow(core_worker).to receive(:finalize_shutdown)
      allow(Temporalio::Worker::ActivityWorker).to receive(:new).and_return(activity_worker)
      allow(activity_worker).to receive(:setup_graceful_shutdown_timer).and_return(nil)
      allow(activity_worker).to receive(:run).and_return(nil)
      allow(Temporalio::Worker::ThreadPoolExecutor).to receive(:new).and_return(activity_executor)
      allow(activity_executor).to receive(:shutdown).and_call_original

      subject.start
    end

    it 'calls shutdown on all workers' do
      subject.shutdown

      expect(core_worker).to have_received(:initiate_shutdown).ordered
      expect(activity_worker).to have_received(:setup_graceful_shutdown_timer).ordered
      expect(activity_worker).to have_received(:drain).ordered
      expect(activity_executor).to have_received(:shutdown).ordered
      expect(core_worker).to have_received(:finalize_shutdown).ordered
    end
  end

  describe '#started?' do
    it 'returns true when worker is started' do
      subject.instance_variable_set(:@started, true)

      expect(subject).to be_started
    end

    it 'returns false when worker is not started' do
      subject.instance_variable_set(:@started, false)

      expect(subject).not_to be_started
    end
  end

  describe '#running?' do
    it 'returns true when worker is started and not shuting down' do
      subject.instance_variable_set(:@started, true)
      subject.instance_variable_set(:@shutdown, false)

      expect(subject).to be_running
    end

    it 'returns false when worker is not started' do
      subject.instance_variable_set(:@started, false)

      expect(subject).not_to be_running
    end

    it 'returns false when worker is started but not shutting down' do
      subject.instance_variable_set(:@started, true)
      subject.instance_variable_set(:@shutdown, true)

      expect(subject).not_to be_running
    end
  end
end
