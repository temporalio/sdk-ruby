require 'temporal/worker/reactor/promise'

describe Temporal::Worker::Reactor::Promise do
  subject { described_class.new }

  let(:test_error) { StandardError.new('test error') }

  describe '#fulfilled?' do
    it 'is not fulfilled by default' do
      expect(subject).not_to be_fulfilled
    end

    it 'returns false when unfulfilled' do
      Fiber.new { subject.wait }.resume

      expect(subject).not_to be_fulfilled
    end

    it 'returns true when fulfilled' do
      Fiber.new { subject.wait }.resume
      subject.resolve(42)

      expect(subject).to be_fulfilled
    end
  end

  describe '#result' do
    it 'blocks fiber until resolved and returns result' do
      result = nil

      Fiber.new { result = subject.result }.resume
      subject.resolve(42)

      expect(result).to eq(42)
    end

    it 'blocks fiber until rejected and then raises' do
      caught_error = nil

      Fiber.new do
        subject.result
      rescue StandardError => e
        caught_error = e
      end.resume
      subject.reject(test_error)

      expect(caught_error).to eq(test_error)
    end
  end

  describe '#resolve' do
    before { Fiber.new { subject.wait }.resume }

    it 'resolves a promise with a value' do
      subject.resolve('test value')

      expect(subject.result).to eq('test value')
      expect(subject).to be_fulfilled
    end

    it 'raises if promise is already resolved' do
      subject.resolve('test value')

      expect { subject.resolve('test value') }
        .to raise_error(described_class::AlreadyFulfilledError)
    end

    it 'raises if promise is already rejected' do
      subject.reject(test_error)

      expect { subject.resolve('test value') }
        .to raise_error(described_class::AlreadyFulfilledError)
    end
  end

  describe '#reject' do
    before { Fiber.new { subject.wait }.resume }

    it 'rejects a promise with an exception' do
      subject.reject(test_error)

      expect { subject.result }.to raise_error(test_error)
      expect(subject).to be_fulfilled
    end

    it 'raises if promise is already resolved' do
      subject.resolve('test value')

      expect { subject.reject(test_error) }
        .to raise_error(described_class::AlreadyFulfilledError)
    end

    it 'raises if promise is already rejected' do
      subject.reject(test_error)

      expect { subject.reject(test_error) }
        .to raise_error(described_class::AlreadyFulfilledError)
    end
  end
end
