require 'temporal/activity/context'
require 'temporal/activity/info'

describe Temporal::Activity::Context do
  let(:info) { Temporal::Activity::Info.new }

  describe '#heartbeat' do
    it 'calls the provided proc' do
      received_details = nil
      heartbeat = ->(*details) { received_details = details }

      context = described_class.new(info, heartbeat)
      context.heartbeat('foo', 'bar')

      expect(received_details).to eq(%w[foo bar])
    end
  end
end
