require 'temporalio/worker/reactor'

describe Temporalio::Worker::Reactor do
  subject { described_class.new }

  describe '#async' do
    let(:reactor) { Async::Reactor.new }

    before do
      allow(reactor).to receive(:run).and_call_original
      allow(Async::Reactor).to receive(:new).and_return(reactor)
    end

    it 'executes a given block inside a reactor' do
      queue = Queue.new

      subject.async do |task|
        task.async { queue << Thread.current.object_id }
      end

      result = queue.pop
      expect(result).not_to be_nil
      expect(result).not_to eq(Thread.current.object_id)
    end
  end
end
