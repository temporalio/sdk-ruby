require 'temporal/worker/reactor'

describe Temporal::Worker::Reactor do
  subject { described_class.instance }

  describe '#execute' do
    it 'executes a task' do
      performed = false

      subject.execute { performed = true }
      subject.attach

      expect(performed).to eq(true)
    end
  end

  describe '#async' do
    it 'runs tasks asynchronously' do
      tasks = []

      subject.execute do |reactor|
        promise_1 = reactor.async do |r|
          tasks << :start_1
          r.call(:finish_1)
        end

        promise_2 = reactor.async do |r|
          tasks << :start_2
          r.call(:finish_2)
        end

        tasks << promise_1.result
        tasks << promise_2.result
      end
      subject.attach

      expect(tasks).to eq(%i[start_1 start_2 finish_1 finish_2])
    end
  end

  describe '#await' do
    it 'runs tasks synchronously' do
      tasks = []

      subject.execute do |reactor|
        tasks << reactor.await do |r|
          tasks << :start_1
          r.call(:finish_1)
        end

        tasks << reactor.await do |r|
          tasks << :start_2
          r.call(:finish_2)
        end
      end
      subject.attach

      expect(tasks).to eq(%i[start_1 finish_1 start_2 finish_2])
    end
  end
end
