require 'temporalio/testing'

describe Temporalio::Testing do
  subject { described_class }
  let(:core_server) { instance_double(Temporalio::Bridge::TestServer, target: 'localhost:12345') }
  let(:core_connection) { instance_double(Temporalio::Bridge::Connection) }

  before do
    allow(Temporalio::Bridge::Connection)
      .to receive(:connect)
      .with(
        an_instance_of(Temporalio::Bridge::Runtime),
        an_instance_of(Temporalio::Bridge::ConnectOptions), # Temporalio::Bridge::ConnectOptions.new(url: 'http://localhost:12345', tls: nil),
      )
      .and_return(core_connection)
  end

  describe '.start_local_environment' do
    before do
      allow(Temporalio::Bridge::TestServer).to receive(:start_temporalite).and_return(core_server)
    end

    it 'starts a new Temporalite server and returns a WorkflowEnvironment' do
      env = subject.start_local_environment

      expect(env).to be_a(Temporalio::Testing::WorkflowEnvironment)
      expect(env.connection).to be_a(Temporalio::Connection)
      expect(env.client).to be_a(Temporalio::Client)
      expect(env.client.namespace).to eq(described_class::DEFAULT_NAMESPACE)

      expect(Temporalio::Bridge::TestServer)
        .to have_received(:start_temporalite)
        .with(
          an_instance_of(Temporalio::Bridge::Runtime),
          nil,
          'sdk-ruby',
          Temporalio::VERSION,
          'default',
          nil,
          described_class::DEFAULT_NAMESPACE,
          '127.0.0.1',
          nil,
          nil,
          false,
          'pretty',
          'warn',
          [],
        )
    end

    context 'with supplied arguments' do
      it 'starts a new Temporalite server with the provided arguments' do
        env = subject.start_local_environment(
          namespace: 'test-namespace',
          ip: '10.0.0.5',
          port: 12345, # rubocop:disable Style/NumericLiterals
          download_dir: '/tmp/download_dir',
          ui: true,
          temporalite_existing_path: '/tmp/existing_dir',
          temporalite_database_filename: 'test-db',
          temporalite_log_format: 'pretty',
          temporalite_log_level: 'debug',
          temporalite_download_version: '0.0.42',
          temporalite_extra_args: %w[arg1 arg2],
        )

        expect(env).to be_a(Temporalio::Testing::WorkflowEnvironment)
        expect(env.connection).to be_a(Temporalio::Connection)

        expect(Temporalio::Bridge::TestServer)
          .to have_received(:start_temporalite)
          .with(
            an_instance_of(Temporalio::Bridge::Runtime),
            '/tmp/existing_dir',
            'sdk-ruby',
            Temporalio::VERSION,
            '0.0.42',
            '/tmp/download_dir',
            'test-namespace',
            '10.0.0.5',
            12345, # rubocop:disable Style/NumericLiterals
            'test-db',
            true,
            'pretty',
            'debug',
            %w[arg1 arg2],
          )
      end
    end

    context 'with a block' do
      before { allow(core_server).to receive(:shutdown) }

      it 'shuts down a the server automatically' do
        subject.start_local_environment do |env|
          expect(env).to be_a(Temporalio::Testing::WorkflowEnvironment)
          expect(env.connection).to be_a(Temporalio::Connection)
          expect(env.client).to be_a(Temporalio::Client)
        end

        expect(core_server).to have_received(:shutdown)
      end

      it 'shuts down the server if a block raises' do
        expect do
          subject.start_local_environment { raise 'test error' }
        end.to raise_error('test error')

        expect(core_server).to have_received(:shutdown)
      end
    end
  end

  describe '.start_time_skipping_environment' do
    before do
      allow(Temporalio::Bridge::TestServer).to receive(:start).and_return(core_server)
    end

    it 'starts a new Test server and returns a WorkflowEnvironment' do
      env = subject.start_time_skipping_environment

      expect(env).to be_a(Temporalio::Testing::WorkflowEnvironment)
      expect(env.connection).to be_a(Temporalio::Connection)
      expect(env.client).to be_a(Temporalio::Client)
      expect(env.client.namespace).to eq(described_class::DEFAULT_NAMESPACE)

      expect(Temporalio::Bridge::TestServer)
        .to have_received(:start)
        .with(
          an_instance_of(Temporalio::Bridge::Runtime),
          nil,
          'sdk-ruby',
          Temporalio::VERSION,
          'default',
          nil,
          nil,
          [],
        )
    end

    context 'with supplied arguments' do
      it 'starts a new Test server with the provided arguments' do
        env = subject.start_time_skipping_environment(
          port: 12345, # rubocop:disable Style/NumericLiterals
          download_dir: '/tmp/download_dir',
          test_server_existing_path: '/tmp/existing_path',
          test_server_download_version: '0.42.0',
          test_server_extra_args: %w[arg1 arg2],
        )

        expect(env).to be_a(Temporalio::Testing::WorkflowEnvironment)
        expect(env.connection).to be_a(Temporalio::Connection)

        expect(Temporalio::Bridge::TestServer)
          .to have_received(:start)
          .with(
            an_instance_of(Temporalio::Bridge::Runtime),
            '/tmp/existing_path',
            'sdk-ruby',
            Temporalio::VERSION,
            '0.42.0',
            '/tmp/download_dir',
            12345, # rubocop:disable Style/NumericLiterals
            %w[arg1 arg2],
          )
      end
    end

    context 'with a block' do
      before { allow(core_server).to receive(:shutdown) }

      it 'shuts down a the server automatically' do
        subject.start_time_skipping_environment do |env|
          expect(env).to be_a(Temporalio::Testing::WorkflowEnvironment)
          expect(env.connection).to be_a(Temporalio::Connection)
          expect(env.client).to be_a(Temporalio::Client)
        end

        expect(core_server).to have_received(:shutdown)
      end

      it 'shuts down the server if a block raises' do
        expect do
          subject.start_time_skipping_environment { raise 'test error' }
        end.to raise_error('test error')

        expect(core_server).to have_received(:shutdown)
      end
    end
  end
end
