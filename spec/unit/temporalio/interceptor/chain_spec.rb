require 'support/helpers/test_simple_interceptor'
require 'temporalio/activity/info'
require 'temporalio/interceptor/chain'

describe Temporalio::Interceptor::Chain do
  subject { described_class.new(interceptors) }

  describe '#invoke' do
    let(:interceptors) do
      [
        Helpers::TestSimpleInterceptor.new('a'),
        Helpers::TestSimpleInterceptor.new('b'),
      ]
    end

    it 'calls each interceptors' do
      result = subject.invoke(:start_workflow, []) do |input|
        input << 'main'
        input
      end

      expect(result).to eq(%w[before_a before_b main after_b after_a])
    end

    it 'works for methods that take no arguments' do
      result = subject.invoke(:info) do
        Temporalio::Activity::Info.new(heartbeat_details: ['main'])
      end

      expect(result).to be_a(Temporalio::Activity::Info)
      expect(result.heartbeat_details).to eq(%w[main b a])
    end

    context 'without interceptors' do
      let(:interceptors) { [] }

      it 'calls the block' do
        result = subject.invoke(:start_workflow, []) do |input|
          input << 'main'
          input
        end

        expect(result).to eq(%w[main])
      end

      it 'works for methods that take no arguments' do
        result = subject.invoke(:info) do
          Temporalio::Activity::Info.new(heartbeat_details: ['main'])
        end

        expect(result).to be_a(Temporalio::Activity::Info)
        expect(result.heartbeat_details).to eq(%w[main])
      end
    end
  end
end
