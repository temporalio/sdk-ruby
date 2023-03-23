require 'temporalio/interceptor'

class TestActivityInboundInterceptor
  include Temporalio::Interceptor::ActivityInbound
end

class TestActivityOutboundInterceptor
  include Temporalio::Interceptor::ActivityOutbound
end

describe Temporalio::Interceptor do
  let(:activity_inbound) { TestActivityInboundInterceptor.new }
  let(:activity_outbound_1) { TestActivityOutboundInterceptor.new }
  let(:activity_outbound_2) { TestActivityOutboundInterceptor.new }

  let(:interceptors) do
    [
      activity_inbound,
      activity_outbound_1,
      activity_outbound_2,
    ]
  end

  describe '.filter' do
    it 'returns an array of specified interceptors' do
      expect(described_class.filter(interceptors, :activity_inbound)).to eq([activity_inbound])
      expect(described_class.filter(interceptors, :activity_outbound))
        .to eq([activity_outbound_1, activity_outbound_2])
    end
  end
end
