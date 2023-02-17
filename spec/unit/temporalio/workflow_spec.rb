require 'temporalio/workflow'
require 'temporalio/workflow/context'

class TestSimpleWorkflow < Temporalio::Workflow; end

class TestWorkflowWithCustomName < Temporalio::Workflow
  workflow_name 'custom-workflow-name'
end

describe Temporalio::Workflow do
  subject { described_class.new(context) }
  let(:context) { instance_double(Temporalio::Workflow::Context) }

  describe '._name' do
    it 'returns class name by default' do
      expect(TestSimpleWorkflow._name).to eq('TestSimpleWorkflow')
    end

    it 'returns class name when overriden' do
      expect(TestWorkflowWithCustomName._name).to eq('custom-workflow-name')
    end
  end

  describe '#async' do
    let(:block) { -> { 42 } }

    before { allow(context).to receive(:async) }

    it 'gets delegated to context' do
      subject.async(&block)

      expect(context).to have_received(:async) do |&b|
        expect(b).to eq(block)
      end
    end
  end

  describe '#sleep' do
    before { allow(context).to receive(:sleep) }

    it 'gets delegated to context' do
      subject.sleep(42)

      expect(context).to have_received(:sleep).with(42)
    end
  end

  describe '#now' do
    before { allow(context).to receive(:now) }

    it 'gets delegated to context' do
      subject.now

      expect(context).to have_received(:now)
    end
  end

  describe '#workflow' do
    it 'returns context context' do
      expect(subject.send(:workflow)).to eq(context)
    end
  end
end
