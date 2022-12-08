require 'temporal/activity'

class TestSimpleActivity < Temporal::Activity; end

class TestActivityWithCustomName < Temporal::Activity
  activity_name 'custom-activity-name'
end

class TestShieldedActivity < Temporal::Activity
  shielded
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

  describe '._shielded' do
    it 'returns false for non-shielded activities' do
      expect(TestSimpleActivity._shielded).to eq(false)
    end

    it 'returns class name when overriden' do
      expect(TestShieldedActivity._shielded).to eq(true)
    end
  end
end
