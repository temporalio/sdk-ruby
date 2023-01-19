require 'temporalio/testing'

describe Temporalio::Testing do
  describe '.start_local_environment' do
    it 'starts a new Temporalite server and returns a WorkflowEnvironment' do
      Temporalio::Testing.start_local_environment(
        namespace: 'test-namespace',
        port: 12345, # rubocop:disable Style/NumericLiterals
        download_dir: './tmp/',
        temporalite_log_format: 'pretty',
        temporalite_log_level: 'error',
      ) do |env|
        expect(env).to be_a(Temporalio::Testing::WorkflowEnvironment)
        expect(env.connection).to be_a(Temporalio::Connection)
        expect(env.current_time).to be_within(1).of(Time.now)
      end
    end
  end

  describe '.start_time_skipping_environment' do
    it 'starts a new Test server and returns a WorkflowEnvironment' do
      Temporalio::Testing.start_time_skipping_environment(
        port: 12345, # rubocop:disable Style/NumericLiterals
        download_dir: './tmp/'
      ) do |env|
        expect(env).to be_a(Temporalio::Testing::WorkflowEnvironment)
        expect(env.connection).to be_a(Temporalio::Connection)
        expect(env.current_time).to be_within(1).of(Time.now)
      end
    end
  end
end
