require 'temporal/worker'
require 'temporal/async_reactor'

describe Temporal::AsyncReactor do
  let(:reactor) { described_class.new }

  describe "#sync" do
    it "blocks on sync blocks" do
      called = []
      reactor.async do
        reactor.sync do
          sleep(0.2)
          called << 1
        end
        reactor.async do
          called << 2
        end
      end
      expect(called).to eq [1,2]
    end
  end

  describe "#async" do
    it "runs async blocks" do
      called = []
      start = Time.now

      reactor.async do
        10.times do |i|
          reactor.async { sleep(1); called << i }
        end
      end
      elapsed = Time.now - start
      expect(called).to eq (0...10).to_a
      expect(elapsed).to be > 1
      expect(elapsed).to be < 2
    end
  end
end
