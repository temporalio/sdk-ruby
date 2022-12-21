require 'support/helpers/test_simple_interceptor'
require 'temporalio/interceptor/chain'
require 'temporalio/interceptor/client'

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

    context 'without interceptors' do
      let(:interceptors) { [] }

      it 'calls the block' do
        result = subject.invoke(:start_workflow, []) do |input|
          input << 'main'
          input
        end

        expect(result).to eq(%w[main])
      end
    end
  end
end
