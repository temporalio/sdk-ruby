require 'temporalio/workflow/future'

describe Temporalio::Workflow::Future do
  let(:error) { StandardError.new('test error') }
  let(:pending) { ->(_, _, _) {} }
  let(:value) { 42 }
  let(:resolved) { ->(_, resolve, _reject) { resolve.call(value) } }
  let(:rejected) { ->(_, _resolve, reject) { reject.call(error) } }

  after { described_class.current = nil }

  describe '.current' do
    let(:future) { described_class.new(&pending) }

    it 'returns a thread-local future' do
      expect(described_class.current).to eq(nil)
      described_class.current = future
      expect(described_class.current).to eq(future)
    end
  end

  describe '#initialize' do
    it 'yields with a handler for resolving' do
      future = described_class.new do |f, resolve, _reject|
        expect(f).to be_a(described_class)
        resolve.call(42)
      end

      expect(future).to be_resolved
      expect(future.await).to eq(42)
    end

    it 'yields with a handler for rejecting' do
      future = described_class.new do |f, _resolve, reject|
        expect(f).to be_a(described_class)
        reject.call(error)
      end

      expect(future).to be_rejected
      expect { future.await }.to raise_error(error)
    end

    it 'chains cancellation to the parent future' do
      parent = described_class.new(&pending)
      described_class.current = parent

      child = described_class.new do |future, _resolve, reject|
        future.on_cancel { reject.call(error) }
      end

      parent.cancel

      expect(child).to be_rejected
      expect { child.await }.to raise_error(error)
    end
  end

  describe '#then' do
    it 'returns a new future' do
      future = described_class.new(&pending)

      expect(future.then(&pending)).to be_a(described_class)
    end

    context 'when not yet completed' do
      it 'yields the future into the block after resolving' do
        resolve = nil
        future = described_class.new { |_, r, _| resolve = r }
        then_future = future.then { 42 }

        expect(future).to be_pending
        expect(then_future).to be_pending
        resolve.call(nil)
        expect(future).to be_resolved
        expect(then_future).to be_resolved
        expect(then_future.await).to eq(42)
      end

      it 'yields the future into the block after rejecting' do
        reject = nil
        future = described_class.new { |_, _, r| reject = r }
        then_future = future.then { 42 }

        expect(future).to be_pending
        expect(then_future).to be_pending
        reject.call(error)
        expect(future).to be_rejected
        expect(then_future).to be_resolved
        expect(then_future.await).to eq(42)
      end

      it 'rejects the future if the block throws' do
        resolve = nil
        future = described_class.new { |_, r, _| resolve = r }
        then_future = future.then { raise error }

        expect(future).to be_pending
        expect(then_future).to be_pending
        resolve.call(nil)
        expect(future).to be_resolved
        expect(then_future).to be_rejected
        expect { then_future.await }.to raise_error(error)
      end

      it 'calls the block in a new Fiber' do
        resolve = nil
        fiber = nil
        future = described_class.new { |_, r, _| resolve = r }
        then_future = future.then do
          fiber = Fiber.current
          Fiber.yield
        end

        expect(future).to be_pending
        expect(then_future).to be_pending
        resolve.call(nil)

        expect(future).to be_resolved
        expect(then_future).to be_pending

        fiber.resume(42)
        expect(future).to be_resolved
        expect(then_future).to be_resolved
        expect(then_future.await).to eq(42)
      end
    end

    context 'when already resolved' do
      let(:future) { described_class.new(&resolved) }

      it 'yields immediately' do
        expect { |block| future.then(&block) }
          .to yield_with_args(future)
      end
    end

    context 'when already rejected' do
      let(:future) { described_class.new(&rejected) }

      it 'yields immediately' do
        expect { |block| future.then(&block) }
          .to yield_with_args(future)
      end
    end
  end

  describe '#on_cancel' do
    it 'yields if the future is resolved' do
      future = described_class.new(&resolved)
      expect { |block| future.on_cancel(&block) }.to yield_control
    end

    it 'yields if the future is rejected' do
      future = described_class.new(&rejected)
      expect { |block| future.on_cancel(&block) }.to yield_control
    end

    it 'yields if the future is pending, but cancel was requested' do
      future = described_class.new(&pending)
      future.cancel
      expect { |block| future.on_cancel(&block) }.to yield_control
    end

    it 'does not yield if the future is pending and cancel was not requested' do
      future = described_class.new(&pending)
      expect { |block| future.on_cancel(&block) }.not_to yield_control
    end

    it 'yields when the future gets cancelled' do
      yielded = false
      future = described_class.new(&pending)
      future.on_cancel { yielded = true }
      expect(yielded).to eq(false)
      future.cancel
      expect(yielded).to eq(true)
    end
  end

  describe '#pending?' do
    it 'returns true when the future is pending' do
      future = described_class.new(&pending)
      expect(future).to be_pending
    end

    it 'returns true when the future is pending and cancel was requested' do
      future = described_class.new(&pending)
      future.cancel
      expect(future).to be_pending
    end

    it 'returns false when the future is resolved' do
      future = described_class.new(&resolved)
      expect(future).not_to be_pending
    end

    it 'returns false when the future is rejected' do
      future = described_class.new(&rejected)
      expect(future).not_to be_pending
    end
  end

  describe '#resolved?' do
    it 'returns true when the future is resolved' do
      future = described_class.new(&resolved)
      expect(future).to be_resolved
    end

    it 'returns false when the future is pending' do
      future = described_class.new(&pending)
      expect(future).not_to be_resolved
    end

    it 'returns false when the future is rejected' do
      future = described_class.new(&rejected)
      expect(future).not_to be_resolved
    end
  end

  describe '#rejected?' do
    it 'returns true when the future is rejected' do
      future = described_class.new(&rejected)
      expect(future).to be_rejected
    end

    it 'returns false when the future is pending' do
      future = described_class.new(&pending)
      expect(future).not_to be_rejected
    end

    it 'returns false when the future is resolved' do
      future = described_class.new(&resolved)
      expect(future).not_to be_rejected
    end
  end

  describe '#await' do
    it 'returns value if the future was resolved' do
      future = described_class.new(&resolved)
      expect(future.await).to eq(value)
    end

    it 'raises if the future was rejected' do
      future = described_class.new(&rejected)
      expect { future.await }.to raise_error(error)
    end

    it 'yields while the future is pending' do
      resolve = nil
      finished = false
      fiber = Fiber.new do
        future = described_class.new { |_, r, _| resolve = r }
        future.await
        finished = true
      end

      fiber.resume
      expect(fiber).to be_alive
      expect(finished).to eq(false)

      resolve.call(nil)
      expect(fiber).not_to be_alive
      expect(finished).to eq(true)
    end
  end

  describe '#cancel' do
    it 'calls all cancel callbacks in their original order' do
      cancellations = []
      future = described_class.new(&pending)
      future.on_cancel { cancellations << 1 }
      future.on_cancel { cancellations << 2 }
      future.on_cancel { cancellations << 3 }

      future.cancel
      expect(cancellations).to eq([1, 2, 3])

      # it has no effect when called repeatedly
      future.cancel
      expect(cancellations).to eq([1, 2, 3])
    end

    it 'it has no effect when called on a resolved future' do
      resolve = nil
      cancellations = []
      future = described_class.new { |_, r, _| resolve = r }
      future.on_cancel { cancellations << 1 }
      future.on_cancel { cancellations << 2 }
      future.on_cancel { cancellations << 3 }
      resolve.call(nil)

      future.cancel
      expect(cancellations).to eq([])
    end
  end
end
