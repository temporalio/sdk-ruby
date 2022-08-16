require 'temporal/executors'

describe Temporal::Executors do
  let(:executor) { described_class.new }

  describe "#execute" do
    subject(:execute) { executor.execute(fake_task) }
    let(:fake_task) { Struct.new(:id, :executed).new("test") }

    it "executes the given block" do
      execute
      expect(fake_task.executed).to be true
    end
  end
end
