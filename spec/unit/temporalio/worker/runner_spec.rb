require 'temporalio/worker'
require 'temporalio/worker/runner'

describe Temporalio::Worker::Runner do
  subject { described_class.new(worker_one, worker_two) }
  let(:worker_one) { instance_double(Temporalio::Worker, start: nil, shutdown: nil) }
  let(:worker_two) { instance_double(Temporalio::Worker, start: nil, shutdown: nil) }

  describe '#initialize' do
    it 'raises when initialized without workers' do
      expect do
        described_class.new
      end.to raise_error(ArgumentError, 'Must be initialized with at least one worker')
    end
  end

  describe '#run' do
    it 'starts each worker and then shuts them down' do
      Thread.new do
        sleep 0.1
        subject.shutdown
      end

      subject.run

      expect(worker_one).to have_received(:start).with(subject)
      expect(worker_two).to have_received(:start).with(subject)
      expect(worker_two).to have_received(:shutdown)
      expect(worker_two).to have_received(:shutdown)
    end

    it 'calls the provided block and the shuts down' do
      expect { |b| subject.run(&b) }.to yield_control

      expect(worker_one).to have_received(:start).with(subject)
      expect(worker_two).to have_received(:start).with(subject)
      expect(worker_two).to have_received(:shutdown)
      expect(worker_two).to have_received(:shutdown)
    end

    it 're-raises when block raises and performs shutdown' do
      expect do
        subject.run { raise 'test error' }
      end.to raise_error('test error')

      expect(worker_two).to have_received(:shutdown)
      expect(worker_two).to have_received(:shutdown)
    end

    it 'does not re-raise when a shutdown error was raised' do
      subject.run { raise Temporalio::Error::WorkerShutdown }

      expect(worker_two).to have_received(:shutdown)
      expect(worker_two).to have_received(:shutdown)
    end
  end

  describe '#shutdown' do
    let(:start) { Queue.new }

    it 'does nothing if worker is not running' do
      subject.shutdown

      expect(worker_two).not_to have_received(:shutdown)
      expect(worker_two).not_to have_received(:shutdown)
    end

    it 'shuts each worker down' do
      thread = Thread.new do
        subject.run do
          start.close # let the main thread know the workers are running
          sleep
        end
      end

      start.pop
      subject.shutdown

      thread.join # wait for runner to stop

      expect(worker_two).to have_received(:shutdown)
      expect(worker_two).to have_received(:shutdown)
    end

    it 'raises a given exception' do
      thread = Thread.new do
        subject.run do
          start.close # let the main thread know the workers are running
          sleep
        end
      end

      start.pop
      subject.shutdown(RuntimeError.new('test error'))

      thread.report_on_exception = false
      expect { thread.join }.to raise_error(RuntimeError, 'test error')

      expect(worker_two).to have_received(:shutdown)
      expect(worker_two).to have_received(:shutdown)
    end
  end
end
