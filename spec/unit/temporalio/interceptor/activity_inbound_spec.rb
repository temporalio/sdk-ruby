require 'temporalio/interceptor/activity_inbound'

class TestActivityInboundInterceptor
  include Temporalio::Interceptor::ActivityInbound
end

describe Temporalio::Interceptor::ActivityInbound do
  subject { TestActivityInboundInterceptor.new }

  describe '#execute_activity' do
    let(:input) { Temporalio::Interceptor::ActivityInbound::ExecuteActivityInput.new }

    it 'yields' do
      expect { |b| subject.execute_activity(input, &b) }.to yield_with_args(input)
    end
  end
end
