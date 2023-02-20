require 'temporal/api/common/v1/message_pb'
require 'temporal/api/failure/v1/message_pb'
require 'temporal/sdk/core/activity_task/activity_task_pb'
require 'temporalio/activity'
require 'temporalio/data_converter'
require 'temporalio/interceptor/activity_inbound'
require 'temporalio/interceptor/chain'
require 'temporalio/worker/activity_runner'
require 'temporalio/worker/sync_worker'

class TestActivityRunnerInterceptor
  include Temporalio::Interceptor::ActivityInbound
end

class TestRunnableActivity < Temporalio::Activity
  def execute(command)
    case command
    when 'foo'
      'bar'
    when 'fail'
      raise StandardError, 'Test failure'
    when 'heartbeat'
      activity.heartbeat('test')
    end
  end
end

describe Temporalio::Worker::ActivityRunner do
  subject do
    described_class.new(
      TestRunnableActivity,
      task,
      task_queue,
      token,
      worker,
      converter,
      Temporalio::Interceptor::Chain.new(interceptors),
      Temporalio::Interceptor::Chain.new,
    )
  end
  let(:interceptors) { [] }

  let(:task) do
    Temporalio::Bridge::Api::ActivityTask::Start.new(
      workflow_namespace: 'test-namespace',
      workflow_type: 'test-workflow',
      workflow_execution: { workflow_id: 'test-workflow-id', run_id: 'test-run-id' },
      activity_id: '42',
      activity_type: 'TestRunnableActivity',
      header_fields: converter.to_payload_map(headers),
      input: [converter.to_payload(command)],
      heartbeat_details: [converter.to_payload('heartbeat')],
      scheduled_time: Google::Protobuf::Timestamp.from_time(time),
      current_attempt_scheduled_time: Google::Protobuf::Timestamp.from_time(time),
      started_time: Google::Protobuf::Timestamp.from_time(time),
      attempt: 2,
      schedule_to_close_timeout: Google::Protobuf::Duration.new(seconds: 42, nanos: 999_000_000),
      start_to_close_timeout: Google::Protobuf::Duration.new(seconds: 42, nanos: 999_000_000),
      heartbeat_timeout: Google::Protobuf::Duration.new(seconds: 42, nanos: 999_000_000),
      is_local: false,
    )
  end
  let(:time) { Time.now }
  let(:task_queue) { 'test-task-queue' }
  let(:token) { 'test_token' }
  let(:worker) { instance_double(Temporalio::Worker::SyncWorker) }
  let(:converter) { Temporalio::DataConverter.new }
  let(:headers) { { 'foo' => 'bar' } }

  describe '#run' do
    let(:command) { 'foo' }

    it 'returns a payload with activity result' do
      result = subject.run

      expect(result).to be_an_instance_of(Temporalio::Api::Common::V1::Payload)
      expect(result.data).to eq('"bar"')
    end

    it 'initialized context with activity info' do
      allow(Temporalio::Activity::Context).to receive(:new).and_call_original

      subject.run

      expect(Temporalio::Activity::Context).to have_received(:new) do |info|
        expect(info).to be_an_instance_of(Temporalio::Activity::Info)
        expect(info.activity_id).to eq('42')
        expect(info.activity_type).to eq('TestRunnableActivity')
        expect(info.attempt).to eq(2)
        expect(info.current_attempt_scheduled_time).to eq(time)
        expect(info.heartbeat_details).to eq(['heartbeat'])
        expect(info.heartbeat_timeout).to eq(42.999)
        expect(info).to be_local
        expect(info.schedule_to_close_timeout).to eq(42.999)
        expect(info.scheduled_time).to eq(time)
        expect(info.start_to_close_timeout).to eq(42.999)
        expect(info.started_time).to eq(time)
        expect(info.task_queue).to eq(task_queue)
        expect(info.task_token).to eq(token)
        expect(info.workflow_id).to eq('test-workflow-id')
        expect(info.workflow_namespace).to eq('test-namespace')
        expect(info.workflow_run_id).to eq('test-run-id')
        expect(info.workflow_type).to eq('test-workflow')
      end
    end

    context 'with interceptor' do
      let(:interceptor) { TestActivityRunnerInterceptor.new }
      let(:interceptors) { [interceptor] }

      before { allow(interceptor).to receive(:execute_activity) }

      it 'calls interceptor' do
        subject.run

        expect(interceptor).to have_received(:execute_activity) do |input|
          expect(input).to be_a(Temporalio::Interceptor::ActivityInbound::ExecuteActivityInput)
          expect(input.activity).to eq(TestRunnableActivity)
          expect(input.args).to eq(['foo'])
          expect(input.headers).to eq(headers)
        end
      end
    end

    context 'heartbeat' do
      let(:command) { 'heartbeat' }

      before do
        allow(worker).to receive(:record_activity_heartbeat).and_return(nil)
      end

      it 'supplies a heartbeat proc for the context' do
        subject.run

        expect(worker).to have_received(:record_activity_heartbeat) do |task_token, payloads|
          expect(task_token).to eq(token)
          expect(payloads.length).to eq(1)
          expect(payloads.first.data).to eq('"test"')
        end
      end
    end

    context 'when activity raises' do
      let(:command) { 'fail' }

      it 'returns a failure' do
        result = subject.run

        expect(result).to be_an_instance_of(Temporalio::Api::Failure::V1::Failure)
        expect(result.message).to eq('Test failure')
      end
    end
  end
end
