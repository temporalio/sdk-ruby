require 'temporal/activity'

class TestSimpleActivity < Temporal::Activity; end

class TestActivityWithCustomName < Temporal::Activity
  activity_name 'custom-activity-name'
end

describe Temporal::Activity do
  describe '._name' do
    it 'returns class name by default' do
      expect(TestSimpleActivity._name).to eq('TestSimpleActivity')
    end

    it 'returns class name when overriden' do
      expect(TestActivityWithCustomName._name).to eq('custom-activity-name')
    end
  end
end
