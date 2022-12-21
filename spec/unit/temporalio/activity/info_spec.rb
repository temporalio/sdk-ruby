require 'temporalio/activity/info'

describe Temporalio::Activity::Info do
  describe '#local?' do
    it 'returns true when local' do
      expect(described_class.new(local: true)).to be_local
    end

    it 'returns false when not local' do
      expect(described_class.new(local: false)).not_to be_local
    end
  end
end
