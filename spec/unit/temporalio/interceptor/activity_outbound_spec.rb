require 'temporalio/interceptor/activity_outbound'

class TestActivityOutboundInterceptor
  include Temporalio::Interceptor::ActivityOutbound
end

describe Temporalio::Interceptor::ActivityOutbound do
  subject { TestActivityOutboundInterceptor.new }

  describe '#activity_info' do
    it 'yields' do
      expect { |b| subject.activity_info(&b) }.to yield_control
    end
  end

  describe '#heartbeat' do
    let(:input) { ['foo', 'bar', 42] }

    it 'yields' do
      expect { |b| subject.heartbeat(*input, &b) }.to yield_with_args(*input)
    end
  end
end
