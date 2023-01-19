require 'temporalio/testing/workflow_environment'

describe Temporalio::Testing::WorkflowEnvironment do
  subject { described_class.new(core_server, connection) }
  let(:core_server) do
    instance_double(
      Temporalio::Bridge::TestServer,
      target: 'localhost:12345',
      has_test_service?: time_skipping,
      shutdown: nil,
    )
  end
  let(:time_skipping) { false }
  let(:connection) { instance_double(Temporalio::Connection, test_service: test_service) }
  let(:test_service) { instance_double(Temporalio::Connection::TestService) }

  describe '#sleep' do
    before { allow(Kernel).to receive(:sleep) }

    it 'calls Kernel.sleep' do
      subject.sleep(42)

      expect(Kernel).to have_received(:sleep).with(42)
    end

    context 'when supports_time_skipping' do
      let(:time_skipping) { true }

      before do
        allow(test_service)
          .to receive(:unlock_time_skipping_with_sleep)
          .and_return(Temporalio::Api::TestService::V1::SleepResponse.new)
      end

      it 'sends a request to the test server' do
        subject.sleep(42)

        expect(Kernel).not_to have_received(:sleep)
        expect(test_service).to have_received(:unlock_time_skipping_with_sleep) do |request|
          expect(request).to be_a(Temporalio::Api::TestService::V1::SleepRequest)
          expect(request.duration.seconds).to eq(42)
        end
      end
    end
  end

  describe '#current_time' do
    it 'calls Time.now' do
      expect(subject.current_time).to be_within(1).of(Time.now)
    end

    context 'when supports_time_skipping' do
      let(:time_skipping) { true }

      before do
        allow(test_service)
          .to receive(:get_current_time)
          .and_return(Temporalio::Api::TestService::V1::GetCurrentTimeResponse.new(time: Time.now))
      end

      it 'sends a request to the test server' do
        expect(subject.current_time).to be_within(1).of(Time.now)
        expect(test_service).to have_received(:get_current_time)
      end
    end
  end

  describe '#supports_time_skipping?' do
    it 'returns false by default' do
      expect(subject.supports_time_skipping?).to eq(false)
    end

    context 'when supports_time_skipping' do
      let(:time_skipping) { true }

      it 'returns true' do
        expect(subject.supports_time_skipping?).to eq(true)
      end
    end
  end

  describe '#shutdown' do
    it 'tells server to shut down' do
      subject.shutdown

      expect(core_server).to have_received(:shutdown)
    end
  end

  describe '#with_time_skipping' do
    it 'yields the block given' do
      expect { |b| subject.with_time_skipping(&b) }.to yield_control
    end

    context 'when supports_time_skipping' do
      let(:time_skipping) { true }

      before do
        allow(test_service)
          .to receive(:unlock_time_skipping)
          .and_return(Temporalio::Api::TestService::V1::UnlockTimeSkippingResponse.new)

        allow(test_service)
          .to receive(:lock_time_skipping)
          .and_return(Temporalio::Api::TestService::V1::LockTimeSkippingResponse.new)
      end

      it 'unlocks time skipping and then locks it' do
        subject.with_time_skipping do
          expect(test_service)
            .to have_received(:unlock_time_skipping)
            .with(Temporalio::Api::TestService::V1::UnlockTimeSkippingRequest.new)
            .ordered
        end

        expect(test_service)
          .to have_received(:lock_time_skipping)
          .with(Temporalio::Api::TestService::V1::LockTimeSkippingRequest.new)
          .ordered
      end

      it 'locks time skipping in case block raises' do
        expect do
          subject.with_time_skipping do
            expect(test_service)
              .to have_received(:unlock_time_skipping)
              .with(Temporalio::Api::TestService::V1::UnlockTimeSkippingRequest.new)
              .ordered

            raise 'test error'
          end
        end.to raise_error('test error')

        expect(test_service)
          .to have_received(:lock_time_skipping)
          .with(Temporalio::Api::TestService::V1::LockTimeSkippingRequest.new)
          .ordered
      end
    end
  end
end
