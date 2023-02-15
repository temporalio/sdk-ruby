require 'async'
require 'securerandom'
require 'temporal/sdk/core/workflow_activation/workflow_activation_pb'
require 'temporal/sdk/core/workflow_completion/workflow_completion_pb'
require 'temporalio/data_converter'
require 'temporalio/worker/workflow_worker'
require 'temporalio/workflow'

class TestWorkflow < Temporalio::Workflow; end

class TestWorkflow2 < Temporalio::Workflow
  workflow_name 'TestWorkflow'
end

class TestWrongSuperclassWorkflow < Object; end

class TestHelloWorldWorkflow < Temporalio::Workflow
  def execute(name)
    "Hello, #{name}!"
  end
end

class TestTimerWorkflow < Temporalio::Workflow
  def execute(duration)
    workflow.sleep(duration)

    "Slept for #{duration} seconds"
  end
end

describe Temporalio::Worker::WorkflowWorker do
  subject do
    described_class.new(
      namespace,
      task_queue,
      sync_worker,
      workflows,
      converter,
      interceptors,
    )
  end

  let(:namespace) { 'test-namespace' }
  let(:task_queue) { 'test-task-queue' }
  let(:workflows) { [TestWorkflow, TestHelloWorldWorkflow, TestTimerWorkflow] }
  let(:token) { 'test_token' }
  let(:sync_worker) { Temporalio::Worker::SyncWorker.new(core_worker) }
  let(:core_worker) { instance_double(Temporalio::Bridge::Worker) }
  let(:converter) { Temporalio::DataConverter.new }
  let(:interceptors) { [] }

  describe '#initialize' do
    context 'when initialized with an incorrect workflow class' do
      let(:workflows) { [TestWrongSuperclassWorkflow] }

      it 'raises an error' do
        expect { subject }
          .to raise_error(ArgumentError, 'Workflow must be a subclass of Temporalio::Workflow')
      end
    end

    context 'when initialized with the same workflow class twice' do
      let(:workflows) { [TestWorkflow, TestWorkflow] }

      it 'raises an error' do
        expect { subject }
          .to raise_error(ArgumentError, 'More than one workflow named TestWorkflow')
      end
    end

    context 'when initialized with the same workflow name twice' do
      let(:workflows) { [TestWorkflow, TestWorkflow2] }

      it 'raises an error' do
        expect { subject }
          .to raise_error(ArgumentError, 'More than one workflow named TestWorkflow')
      end
    end
  end

  describe '#run' do
    let(:input) { 'test' }
    let(:run_id) { SecureRandom.uuid }
    let(:workflow_id) { SecureRandom.uuid }
    let(:workflow_name) { 'TestHelloWorldWorkflow' }
    let(:start_workflow) do
      Coresdk::WorkflowActivation::WorkflowActivationJob.new(
        start_workflow: Coresdk::WorkflowActivation::StartWorkflow.new(
          workflow_type: workflow_name,
          workflow_id: workflow_id,
          arguments: [converter.to_payload(input)],
          randomness_seed: 123,
        ),
      )
    end

    context 'when processing a single activation' do
      before do
        allow(core_worker).to receive(:complete_workflow_activation).and_yield(nil, nil)
        allow(core_worker).to receive(:poll_workflow_activation).and_invoke(
          ->(&block) { block.call(activation.to_proto) },
          -> { raise(Temporalio::Bridge::Error::WorkerShutdown) },
        )
      end
      let(:activation) do
        Coresdk::WorkflowActivation::WorkflowActivation.new(
          run_id: run_id,
          timestamp: Time.now,
          is_replaying: false,
          jobs: [start_workflow]
        )
      end

      context 'when workflow is not registered' do
        let(:workflow_name) { 'unknown-workflow' }

        it 'responds with a failure' do
          Async { |task| subject.run(task) }

          expect(core_worker).to have_received(:complete_workflow_activation) do |bytes, &_|
            proto = Coresdk::WorkflowCompletion::WorkflowActivationCompletion.decode(bytes)
            expect(proto.run_id).to eq(run_id)
            expect(proto.failed.failure.message).to eq(
              'Workflow unknown-workflow is not registered on this worker, available workflows: ' \
              'TestHelloWorldWorkflow, TestTimerWorkflow, TestWorkflow'
            )
            expect(proto.failed.failure.application_failure_info.type).to eq('NotFoundError')
          end
        end
      end

      context 'when it succeeds' do
        it 'processes an workflow task and sends back the result' do
          Async { |task| subject.run(task) }

          expect(core_worker).to have_received(:complete_workflow_activation) do |bytes, &_|
            proto = Coresdk::WorkflowCompletion::WorkflowActivationCompletion.decode(bytes)
            expect(proto.run_id).to eq(run_id)
            expect(proto.successful.commands.length).to eq(1)
            command = proto.successful.commands.first
            expect(command.variant).to eq(:complete_workflow_execution)
            expect(converter.from_payload(command.complete_workflow_execution.result)).to eq('Hello, test!')
          end
        end
      end
    end

    context 'when processing a multiple activations' do
      before do
        allow(core_worker).to receive(:complete_workflow_activation).and_yield(nil, nil)
        allow(core_worker).to receive(:poll_workflow_activation).and_invoke(
          ->(&block) { block.call(activation_1.to_proto) },
          ->(&block) { block.call(activation_2.to_proto) },
          -> { raise(Temporalio::Bridge::Error::WorkerShutdown) },
        )
      end
      let(:input) { 42 }
      let(:workflow_name) { 'TestTimerWorkflow' }
      let(:activation_1) do
        Coresdk::WorkflowActivation::WorkflowActivation.new(
          run_id: run_id,
          timestamp: Time.now,
          is_replaying: false,
          jobs: [start_workflow]
        )
      end
      let(:activation_2) do
        Coresdk::WorkflowActivation::WorkflowActivation.new(
          run_id: run_id,
          timestamp: Time.now,
          is_replaying: false,
          jobs: [
            Coresdk::WorkflowActivation::WorkflowActivationJob.new(
              fire_timer: Coresdk::WorkflowActivation::FireTimer.new(seq: 1),
            ),
          ]
        )
      end

      it 'processes activations without emptying the cache' do
        Async { |task| subject.run(task) }

        call = 0
        expect(core_worker).to have_received(:complete_workflow_activation).twice do |bytes|
          proto = Coresdk::WorkflowCompletion::WorkflowActivationCompletion.decode(bytes)
          expect(proto.run_id).to eq(run_id)
          expect(proto.successful.commands.length).to eq(1)
          command = proto.successful.commands.first

          if call == 0
            expect(command.variant).to eq(:start_timer)
            expect(command.start_timer.seq).to eq(1)
            expect(command.start_timer.start_to_fire_timeout.to_f).to eq(input.to_f)
          else
            expect(command.variant).to eq(:complete_workflow_execution)
            expect(converter.from_payload(command.complete_workflow_execution.result))
              .to eq('Slept for 42 seconds')
          end

          call += 1
        end
      end
    end

    context 'when handling a fatal error' do
      let(:activation) do
        Coresdk::WorkflowActivation::WorkflowActivation.new(
          run_id: run_id,
          timestamp: Time.now,
          is_replaying: false,
          jobs: [start_workflow]
        )
      end

      before do
        allow(core_worker).to receive(:complete_workflow_activation).and_yield(nil, nil)
        allow(core_worker).to receive(:poll_workflow_activation).and_invoke(
          ->(&block) { block.call(activation.to_proto) },
          -> { raise(Temporalio::Bridge::Error) },
        )
      end

      it 're-raises the error' do
        Async do |task|
          expect { subject.run(task) }.to raise_error(Temporalio::Bridge::Error)
        end
      end
    end
  end
end
