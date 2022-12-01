require 'support/helpers/test_rpc'
require 'temporal/bridge'
require 'temporal/connection'
require 'temporal/data_converter'
require 'temporal/failure_converter/base'
require 'temporal/payload_codec/base'
require 'temporal/payload_converter/base'
require 'temporal/worker'
require 'temporal/worker/activity'
require 'temporal/worker/thread_pool_executor'

describe Temporal::Worker do
  subject { described_class.new(connection, namespace, task_queue) }
  let(:connection) { instance_double(Temporal::Connection, core_connection: core_connection) }
  let(:core_connection) { instance_double(Temporal::Bridge::Connection) }
  let(:core_worker) { instance_double(Temporal::Bridge::Worker) }
  let(:namespace) { 'test-namespace' }
  let(:task_queue) { 'test-task-queue' }

  before { allow(Temporal::Bridge::Worker).to receive(:create).and_return(core_worker) }

  describe '#initialize' do
    before do
      allow(Temporal::Worker::ThreadPoolExecutor).to receive(:new).and_call_original
      allow(Temporal::DataConverter).to receive(:new).and_call_original
    end

    it 'initializes the core worker' do
      described_class.new(connection, namespace, task_queue)

      expect(Temporal::Bridge::Worker)
        .to have_received(:create)
        .with(an_instance_of(Temporal::Bridge::Runtime), core_connection, namespace, task_queue)
    end

    it 'uses a default executor with a default size' do
      described_class.new(connection, namespace, task_queue)

      expect(Temporal::Worker::ThreadPoolExecutor).to have_received(:new).with(100)
    end

    context 'with max_concurrent_activities' do
      it 'uses a default executor with a specified size' do
        described_class.new(connection, namespace, task_queue, max_concurrent_activities: 42)

        expect(Temporal::Worker::ThreadPoolExecutor).to have_received(:new).with(42)
      end
    end

    context 'with a custom payload converter' do
      let(:payload_converter) { instance_double(Temporal::PayloadConverter::Base) }

      it 'passes it to a data converter' do
        described_class.new(connection, namespace, task_queue, payload_converter: payload_converter)

        expect(Temporal::DataConverter).to have_received(:new).with(
          payload_converter: payload_converter,
          payload_codecs: [],
          failure_converter: Temporal::FailureConverter::DEFAULT,
        )
      end
    end

    context 'with custom payload codecs' do
      let(:payload_codecs) do
        [
          instance_double(Temporal::PayloadCodec::Base),
          instance_double(Temporal::PayloadCodec::Base),
        ]
      end

      it 'passes it to a data converter' do
        described_class.new(connection, namespace, task_queue, payload_codecs: payload_codecs)

        expect(Temporal::DataConverter).to have_received(:new).with(
          payload_converter: Temporal::PayloadConverter::DEFAULT,
          payload_codecs: payload_codecs,
          failure_converter: Temporal::FailureConverter::DEFAULT,
        )
      end
    end

    context 'with a custom failure converter' do
      let(:failure_converter) { instance_double(Temporal::FailureConverter::Base) }

      it 'passes it to a data converter' do
        described_class.new(connection, namespace, task_queue, failure_converter: failure_converter)

        expect(Temporal::DataConverter).to have_received(:new).with(
          payload_converter: Temporal::PayloadConverter::DEFAULT,
          payload_codecs: [],
          failure_converter: failure_converter,
        )
      end
    end
  end

  describe '#run' do
    let(:activity_worker) { instance_double(Temporal::Worker::Activity, run: nil) }

    before { allow(Temporal::Worker::Activity).to receive(:new).and_return(activity_worker) }

    it 'runs the workers inside a new reactor' do
      subject.run

      expect(activity_worker).to have_received(:run).with(Async::Task)
    end
  end

  describe '#start' do
    let(:activity_worker) { instance_double(Temporal::Worker::Activity) }
    let(:queue) { Queue.new }

    before do
      allow(activity_worker).to receive(:run) { queue << 'done!' }
      allow(Temporal::Worker::Activity).to receive(:new).and_return(activity_worker)
    end

    it 'runs the workers inside a shared reactor' do
      subject.start

      expect(queue.pop).to eq('done!')
      expect(activity_worker).to have_received(:run).with(Async::Task)
    end

    it 'raises when attempting to start twice' do
      subject.start

      expect { subject.start }.to raise_error('Worker is already running')
    end
  end

  describe '#shutdown' do
    let(:activity_worker) { instance_double(Temporal::Worker::Activity, shutdown: nil) }

    before { allow(Temporal::Worker::Activity).to receive(:new).and_return(activity_worker) }

    it 'calls shutdown on all workers' do
      subject.shutdown

      expect(activity_worker).to have_received(:shutdown)
    end
  end
end
