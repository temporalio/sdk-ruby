require 'temporalio/worker/thread_pool_executor'

describe Temporalio::Worker::ThreadPoolExecutor do
  subject { described_class.new(size) }
  let(:size) { 2 }
  let(:queue) { Queue.new }

  describe '#schedule' do
    it 'runs a given block inside a thread' do
      subject.schedule do
        queue << Thread.current.object_id
      end

      result = queue.pop
      expect(result).not_to be_nil
      expect(result).not_to eq(Thread.current.object_id)
    end
  end

  describe '#shutdown' do
    it 'turns off all threads after they finish processing' do
      subject.schedule do
        sleep 0.1
        queue << '1'
      end

      subject.schedule do
        sleep 0.1
        queue << '2'
      end

      subject.shutdown

      expect(queue.length).to eq(2)
      expect([queue.pop, queue.pop]).to include('1', '2')
    end
  end
end
