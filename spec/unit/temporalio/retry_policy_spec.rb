require 'temporalio/retry_policy'

describe Temporalio::RetryPolicy do
  subject { described_class.new(**valid_attributes) }

  let(:valid_attributes) do
    {
      initial_interval: 1,
      backoff: 1.5,
      max_interval: 5,
      max_attempts: 3,
      non_retriable_errors: [StandardError],
    }
  end

  describe '#validate!' do
    subject { described_class.new(**attributes) }

    let(:unlimited_attempts) do
      {
        initial_interval: 1,
        backoff: 2.0,
        max_interval: 10,
        max_attempts: 0,
        non_retriable_errors: nil,
      }
    end

    shared_examples 'error' do |message|
      it 'raises InvalidRetryPolicy error' do
        expect { subject.validate! }.to raise_error(described_class::Invalid, message)
      end
    end

    context 'with valid attributes' do
      let(:attributes) { valid_attributes }

      it 'does not raise' do
        expect { subject.validate! }.not_to raise_error
      end
    end

    context 'with no retries' do
      let(:attributes) { { max_attempts: 1 } }

      it 'does not raise' do
        expect { subject.validate! }.not_to raise_error
      end
    end

    context 'with unlimited attempts' do
      let(:attributes) { unlimited_attempts }

      it 'does not raise' do
        expect { subject.validate! }.not_to raise_error
      end
    end

    context 'without max_interval' do
      let(:attributes) { valid_attributes.tap { |h| h.delete(:max_interval) } }

      it 'does not raise' do
        expect { subject.validate! }.not_to raise_error
      end
    end

    context 'with invalid attributes' do
      context 'with missing max_attempts' do
        let(:attributes) { valid_attributes.tap { |h| h[:max_attempts] = nil } }

        include_examples 'error', 'Maximum attempts must be specified'
      end

      context 'with negative max_attempts' do
        let(:attributes) { valid_attributes.tap { |h| h[:max_attempts] = -10 } }

        include_examples 'error', 'Maximum attempts cannot be negative'
      end

      context 'with missing :initial_interval' do
        let(:attributes) { valid_attributes.tap { |h| h[:initial_interval] = nil } }

        include_examples 'error', 'Initial interval must be specified'
      end

      context 'with negative :initial_interval' do
        let(:attributes) { valid_attributes.tap { |h| h[:initial_interval] = -10 } }

        include_examples 'error', 'Initial interval cannot be negative'
      end

      context 'with a non-integer :initial_interval' do
        let(:attributes) { valid_attributes.tap { |h| h[:initial_interval] = 0.5 } }

        include_examples 'error', 'Initial interval must be in whole seconds'
      end

      context 'with missing :backoff' do
        let(:attributes) { valid_attributes.tap { |h| h[:backoff] = nil } }

        include_examples 'error', 'Backoff coefficient must be specified'
      end

      context 'with a zero :backoff' do
        let(:attributes) { valid_attributes.tap { |h| h[:backoff] = 0 } }

        include_examples 'error', 'Backoff coefficient cannot be less than 1'
      end

      context 'with a negative max_interval' do
        let(:attributes) { valid_attributes.tap { |h| h[:max_interval] = -10 } }

        include_examples 'error', 'Maximum interval cannot be negative'
      end

      context 'with a max_interval lower than initial_interval' do
        let(:attributes) { valid_attributes.tap { |h| h[:max_interval] = 0 } }

        include_examples 'error', 'Maximum interval cannot be less than initial interval'
      end
    end
  end

  describe '#to_proto' do
    it 'serializes itself into proto' do
      proto = subject.to_proto

      expect(proto).to be_a(Temporalio::Api::Common::V1::RetryPolicy)
      expect(proto.initial_interval.seconds).to eq(subject.initial_interval)
      expect(proto.backoff_coefficient).to eq(subject.backoff)
      expect(proto.maximum_interval.seconds).to eq(subject.max_interval)
      expect(proto.maximum_attempts).to eq(subject.max_attempts)
      expect(proto.non_retryable_error_types.to_a).to eq(['StandardError'])
    end
  end
end
