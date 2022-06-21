require 'grpc'
require 'temporal/connection'
require 'support/mock_server'

describe Temporal::Connection do
  mock_address = '0.0.0.0:4444'.freeze

  subject { described_class.new("http://#{mock_address}") }

  # TODO: Unlike Ruby's native GRPC client the Temporal::Connection doesn't play well with
  #       the GRPC server in a thread. Needs an investigation of potential thread blocking
  before(:all) { @pid = fork { MockServer.run(mock_address) } }
  after(:all) { Process.kill('QUIT', @pid) }

  MockServer.rpc_descs.each do |rpc, desc|
    rpc = ::GRPC::GenericService.underscore(rpc.to_s)

    # TODO: Remove once https://github.com/temporalio/sdk-core/issues/335 fixed
    next if rpc == 'get_workflow_execution_history_reverse'

    describe "##{rpc}" do
      it 'makes an RPC call' do
        expect(subject.public_send(rpc, desc.input.new)).to be_an_instance_of(desc.output)
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
