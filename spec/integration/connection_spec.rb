require 'grpc'
require 'temporalio/connection'
require 'support/helpers/test_rpc'
require 'support/mock_server'

describe Temporalio::Connection do
  mock_address = '0.0.0.0:4444'.freeze

  subject { described_class.new(mock_address) }

  # TODO: For some reason the Bridge doesn't play well with the server in the same
  #       process throwing SegFaults in cases. Needs further investigation
  before(:all) do
    @pid = fork { exec('bundle exec ruby spec/support/mock_server.rb') }
    Helpers::TestRPC.wait(mock_address, 10)
  end
  after(:all) { Process.kill('QUIT', @pid) }

  describe 'WorkflowService' do
    let(:service) { subject.workflow_service }

    MockWorkflowService.rpc_descs.each do |rpc, desc|
      rpc = GRPC::GenericService.underscore(rpc.to_s)

      describe "##{rpc}" do
        it 'makes an RPC call' do
          expect(service.public_send(rpc, desc.input.new)).to be_an_instance_of(desc.output)
        end

        context 'with metadata' do
          it 'makes an RPC call' do
            expect(service.public_send(rpc, desc.input.new, metadata: { 'foo' => 'bar' }))
              .to be_an_instance_of(desc.output)
          end
        end

        context 'with timeout' do
          it 'makes an RPC call' do
            expect(service.public_send(rpc, desc.input.new, timeout: 5_000))
              .to be_an_instance_of(desc.output)
          end
        end
      end
    end
  end

  describe 'TestService' do
    let(:service) { subject.test_service }

    MockTestService.rpc_descs.each do |rpc, desc|
      rpc = GRPC::GenericService.underscore(rpc.to_s)

      # get_current_time does not take any inputs
      next if rpc == 'get_current_time'

      describe "##{rpc}" do
        it 'makes an RPC call' do
          expect(service.public_send(rpc, desc.input.new)).to be_an_instance_of(desc.output)
        end

        context 'with metadata' do
          it 'makes an RPC call' do
            expect(service.public_send(rpc, desc.input.new, metadata: { 'foo' => 'bar' }))
              .to be_an_instance_of(desc.output)
          end
        end

        context 'with timeout' do
          it 'makes an RPC call' do
            expect(service.public_send(rpc, desc.input.new, timeout: 5_000))
              .to be_an_instance_of(desc.output)
          end
        end
      end
    end

    describe '#get_current_time' do
      it 'makes an RPC call' do
        expect(service.get_current_time)
          .to be_an_instance_of(Temporalio::Api::TestService::V1::GetCurrentTimeResponse)
      end

      context 'with metadata' do
        it 'makes an RPC call' do
          expect(service.get_current_time(metadata: { 'foo' => 'bar' }))
            .to be_an_instance_of(Temporalio::Api::TestService::V1::GetCurrentTimeResponse)
        end
      end

      context 'with timeout' do
        it 'makes an RPC call' do
          expect(service.get_current_time(timeout: 5_000))
            .to be_an_instance_of(Temporalio::Api::TestService::V1::GetCurrentTimeResponse)
        end
      end
    end
  end

  describe 'error handling' do
    it 'raises when given invalid url' do
      expect { described_class.new('not_a_real_url') }.to raise_error(Temporalio::Bridge::Error)
    end

    it 'raises when unable to connect' do
      expect { described_class.new('0.0.0.0:3333') }.to raise_error(Temporalio::Bridge::Error)
    end

    it 'raises when given a URL with schema' do
      expect do
        described_class.new('http://localhost:3333')
      end.to raise_error(Temporalio::Error, 'Target host as URL with scheme are not supported')
    end

    it 'raises when incorrect request was provided' do
      request = Temporalio::Api::WorkflowService::V1::GetClusterInfoRequest.new

      expect { subject.workflow_service.describe_namespace(request) }.to raise_error(ArgumentError)
    end

    it 'raises when no request was provided' do
      expect { subject.workflow_service.describe_namespace(nil) }.to raise_error(TypeError)
    end
  end
end
