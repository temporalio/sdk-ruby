require 'grpc'
require 'temporalio/connection'
require 'support/mock_server'
require 'support/grpc/temporal/api/testservice/v1/service_services_pb'
require 'support/grpc/temporal/api/workflowservice/v1/service_services_pb'

class MockTestService < Temporalio::Api::TestService::V1::TestService::Service
  # Automatically add handling for each RPC method returning an empty response
  rpc_descs.each do |rpc, desc|
    define_method(::GRPC::GenericService.underscore(rpc.to_s)) do |_request, _call|
      desc.output.new # return an empty response
    end
  end
end

class MockWorkflowService < Temporalio::Api::WorkflowService::V1::WorkflowService::Service
  # Automatically add handling for each RPC method returning an empty response
  rpc_descs.each do |rpc, desc|
    define_method(::GRPC::GenericService.underscore(rpc.to_s)) do |_request, _call|
      desc.output.new # return an empty response
    end
  end
end

describe Temporalio::Connection do
  describe 'WorkflowService' do
    before(:all) do
      @server, @address = MockServer.start_mock_server(MockWorkflowService.new)
    end

    after(:all) do
      @server.stop
    end

    subject { described_class.new(@address) }
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
    before(:all) do
      @server, @address = MockServer.start_mock_server(MockTestService.new)
    end

    after(:all) do
      @server.stop
    end

    subject { described_class.new(@address) }
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
  end

  describe 'error handling' do
    before(:all) do
      @server, @address = MockServer.start_mock_server(MockWorkflowService.new)
    end

    after(:all) do
      @server.stop
    end

    subject { described_class.new(@address) }
    let(:service) { subject.workflow_service }

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

      expect { service.describe_namespace(request) }.to raise_error(ArgumentError)
    end

    it 'raises when no request was provided' do
      expect { service.describe_namespace(nil) }.to raise_error(TypeError)
    end
  end

  describe 'Metadata' do
    it 'reports the correct client-name and client-version by default' do
      received_metadata = {}

      mock_workflow_service = (Class.new(Temporalio::Api::WorkflowService::V1::WorkflowService::Service) do
        # @param _request [Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionRequest]
        # @param call [GRPC::ActiveCall::SingleReqView]
        define_method :start_workflow_execution do |_request, call|
          call.metadata.each do |key, value|
            received_metadata[key] = value
          end
          Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionResponse.new # Return an empty response
        end
      end).new

      MockServer.with_mock_server(mock_workflow_service) do |address|
        Temporalio::Connection.new(address).workflow_service.start_workflow_execution(
          Temporalio::Api::WorkflowService::V1::StartWorkflowExecutionRequest.new
        )
      end

      expect(received_metadata['client-name']).to eq('temporal-ruby')
      expect(received_metadata['client-version']).to eq(Temporalio::VERSION)
    end
  end
end
