require 'temporalio/workflow/async'
require 'temporalio/workflow/future'

describe Temporalio::Workflow::Async do
  let(:error) { StandardError.new('test error') }

  describe '.run' do
    it 'calls the provided block' do
      expect { |b| described_class.run(&b) }.to yield_control
    end

    it 'sets a current future within the Fiber' do
      expect(Temporalio::Workflow::Future.current).to be_nil
      described_class.run do
        expect(Temporalio::Workflow::Future.current).to be_a(Temporalio::Workflow::Future)
        expect(Temporalio::Workflow::Future.current).to be_pending
      end
      expect(Temporalio::Workflow::Future.current).to be_nil
    end

    it 'returns a Future that gets resolved with the result of the block' do
      future = described_class.run { 42 }

      expect(future).to be_a(Temporalio::Workflow::Future)
      expect(future).to be_resolved
      expect(future.await).to eq(42)
    end

    it 'returns a Future that gets rejected if the block raises' do
      future = described_class.run { raise 'test error' }

      expect(future).to be_a(Temporalio::Workflow::Future)
      expect(future).to be_rejected
      expect { future.await }.to raise_error('test error')
    end
  end

  describe '.all' do
    it 'is not resolved while some futures are pending' do
      future_1 = Temporalio::Workflow::Future.new { nil }
      future_2 = Temporalio::Workflow::Future.new { |_, resolve, _| resolve.call(42) }

      all_future = described_class.all(future_1, future_2)

      expect(all_future).to be_pending
    end

    it 'gets resolved when all the provided futures resolve' do
      future_1 = Temporalio::Workflow::Future.new { |_, resolve, _| resolve.call(42) }
      future_2 = Temporalio::Workflow::Future.new { |_, resolve, _| resolve.call(42) }

      all_future = described_class.all(future_1, future_2)

      expect(all_future).to be_resolved
      expect(all_future.await).to eq(nil)
    end

    it 'gets resolved when all the provided futures are both resolved and rejected' do
      future_1 = Temporalio::Workflow::Future.new { |_, resolve, _| resolve.call(42) }
      future_2 = Temporalio::Workflow::Future.new { |_, _, reject| reject.call(error) }

      all_future = described_class.all(future_1, future_2)

      expect(all_future).to be_resolved
      expect(all_future.await).to eq(nil)
    end

    it 'gets resolved when all the provided futures are rejected' do
      future_1 = Temporalio::Workflow::Future.new { |_, _, reject| reject.call(error) }
      future_2 = Temporalio::Workflow::Future.new { |_, _, reject| reject.call(error) }

      all_future = described_class.all(future_1, future_2)

      expect(all_future).to be_resolved
      expect(all_future.await).to eq(nil)
    end

    it 'delegates cancels to all' do
      future_1 = Temporalio::Workflow::Future.new { nil }
      future_2 = Temporalio::Workflow::Future.new { nil }

      allow(future_1).to receive(:cancel)
      allow(future_2).to receive(:cancel)

      all_future = described_class.all(future_1, future_2)
      all_future.cancel

      expect(future_1).to have_received(:cancel)
      expect(future_2).to have_received(:cancel)
    end
  end

  describe '.any' do
    it 'is not resolved while all futures are pending' do
      future_1 = Temporalio::Workflow::Future.new { nil }
      future_2 = Temporalio::Workflow::Future.new { nil }

      any_future = described_class.any(future_1, future_2)

      expect(any_future).to be_pending
    end

    it 'gets resolved when any of the provided futures gets resolved' do
      future_1 = Temporalio::Workflow::Future.new { nil }
      future_2 = Temporalio::Workflow::Future.new { |_, resolve, _| resolve.call(42) }

      any_future = described_class.any(future_1, future_2)

      expect(any_future).to be_resolved
      expect(any_future.await).to eq(future_2)
    end

    it 'gets resolved when any of the provided futures gets rejected' do
      future_1 = Temporalio::Workflow::Future.new { |_, _, reject| reject.call(error) }
      future_2 = Temporalio::Workflow::Future.new { nil }

      any_future = described_class.any(future_1, future_2)

      expect(any_future).to be_resolved
      expect(any_future.await).to eq(future_1)
    end

    it 'delegates cancels to all' do
      future_1 = Temporalio::Workflow::Future.new { nil }
      future_2 = Temporalio::Workflow::Future.new { nil }

      allow(future_1).to receive(:cancel)
      allow(future_2).to receive(:cancel)

      any_future = described_class.any(future_1, future_2)
      any_future.cancel

      expect(future_1).to have_received(:cancel)
      expect(future_2).to have_received(:cancel)
    end
  end
end
