require 'temporal/converter/json'

class TestCustomSerializableClass < Struct.new(:foo)
  def self.json_create(object)
    new(object['foo'])
  end

  def to_json(*args)
    { JSON.create_id => self.class.name, 'foo' => foo }.to_json(*args)
  end
end

describe Temporal::Converter::JSON do
  subject { described_class.new }

  it 'safely handles non-ASCII encodable UTF characters' do
    input = { 'one' => 'one', ':two' => '☻' }

    expect(subject.from_payload(subject.to_payload(input))).to eq(input)
  end

  it 'handles floats without loss of precision' do
    input = { 'a_float' => 1_626_122_510_001.305986623 }
    result = subject.from_payload(subject.to_payload(input))['a_float']
    expect(result).to be_within(1e-8).of(input['a_float'])
  end

  context 'with custom JSON Additions' do
    it 'preserves the original class' do
      input = TestCustomSerializableClass.new('bar')

      expect(subject.from_payload(subject.to_payload(input))).to eq(input)
    end
  end
end
