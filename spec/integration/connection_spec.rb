require 'grpc'
require 'temporal/connection'
require 'support/mock_server'

describe Temporal::Connection do
  mock_address = '0.0.0.0:4444'.freeze

  def wait_for_mock_server(address, attempts, interval = 1)
    request = Temporal::Api::WorkflowService::V1::GetSystemInfoRequest.new
    attempts.times do |i|
      connection = described_class.new("http://#{address}")
      connection.get_system_info(request)
      break
    rescue StandardError => e
      puts "Error connecting to a mock server: #{e}. Attempt #{i + 1} / #{attempts}"
      raise if i + 1 == attempts # re-raise upon exhausting attempts

      sleep interval
    end
  end

  subject { described_class.new("http://#{mock_address}") }

  # TODO: For some reason the Bridge doesn't play well with the server in the same
  #       process throwing SegFaults in cases. Needs further investigation
  before(:all) do
    @pid = fork { MockServer.run(mock_address) }
    wait_for_mock_server(mock_address, 10)
  end
  after(:all) { Process.kill('QUIT', @pid) }

  MockServer.rpc_descs.each do |rpc, desc|
    rpc = ::GRPC::GenericService.underscore(rpc.to_s)

    # TODO: Remove once https://github.com/temporalio/sdk-core/issues/335 fixed
    next if rpc == 'get_workflow_execution_history_reverse'

    describe "##{rpc}" do
      it 'makes an RPC call' do
        expect(subject.public_send(rpc, desc.input.new)).to be_an_instance_of(desc.output)
      end

      context 'with metadata' do
        it 'makes an RPC call' do
          expect(subject.public_send(rpc, desc.input.new, metadata: { 'foo' => 'bar' }))
            .to be_an_instance_of(desc.output)
        end
      end

      context 'with timeout' do
        it 'makes an RPC call' do
          expect(subject.public_send(rpc, desc.input.new, timeout: 5_000))
            .to be_an_instance_of(desc.output)
        end
      end
    end
  end

  describe 'error handling' do
    it 'raises when given invalid url' do
      expect { described_class.new('not_a_real_url') }.to raise_error(Temporal::Bridge::Error)
    end

    it 'raises when unable to connect' do
      expect { described_class.new('http://0.0.0.0:3333') }.to raise_error(Temporal::Bridge::Error)
    end

    it 'raises when incorrect request was provided' do
      request = Temporal::Api::WorkflowService::V1::GetClusterInfoRequest.new

      expect { subject.describe_namespace(request) }.to raise_error(ArgumentError)
    end

    it 'raises when no request was provided' do
      expect { subject.describe_namespace(nil) }.to raise_error(TypeError)
    end
  end
end
