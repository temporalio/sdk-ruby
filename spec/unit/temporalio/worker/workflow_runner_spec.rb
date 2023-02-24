require 'securerandom'
require 'temporalio/data_converter'
require 'temporalio/worker/sync_worker'
require 'temporalio/worker/workflow_runner'

class TestSimpleTimerWorkflow < Temporalio::Workflow
  def execute(duration)
    workflow.sleep(duration)

    "Slept for #{duration} seconds"
  end
end

class TestInboundWorkflowInterceptor
  attr_reader :output, :input

  def initialize
    @output = []
    @input = nil
  end

  def execute_workflow(input)
    @output << 'before'
    @input = input
    yield(input)
    @output << 'after'

    'Result from interceptor'
  end
end

describe Temporalio::Worker::WorkflowRunner do
  subject do
    described_class.new(
      namespace,
      task_queue,
      workflow_class,
      run_id,
      worker,
      converter,
      Temporalio::Interceptor::Chain.new(inbound_interceptors),
      Temporalio::Interceptor::Chain.new(outbound_interceptors),
    )
  end

  let(:namespace) { 'test-namespace' }
  let(:task_queue) { 'test-task-queue' }
  let(:workflow_class) { TestSimpleTimerWorkflow }
  let(:run_id) { SecureRandom.uuid }
  let(:worker) { instance_double(Temporalio::Worker::SyncWorker) }
  let(:converter) { Temporalio::DataConverter.new }
  let(:inbound_interceptors) { [] }
  let(:outbound_interceptors) { [] }

  # TODO: Test job ordering when more job types are supported
  describe '#process' do
    let(:input) { 42 }
    let(:rand_seed) { 123 }
    let(:time_1) { Time.now }
    let(:time_2) { time_1 + 10 }
    let(:workflow_id) { SecureRandom.uuid }

    let(:activation_1) do
      Temporalio::Bridge::Api::WorkflowActivation::WorkflowActivation.new(
        run_id: run_id,
        timestamp: time_1,
        is_replaying: true,
        jobs: [
          Temporalio::Bridge::Api::WorkflowActivation::WorkflowActivationJob.new(
            start_workflow: Temporalio::Bridge::Api::WorkflowActivation::StartWorkflow.new(
              workflow_type: workflow_class._name,
              workflow_id: workflow_id,
              arguments: [converter.to_payload(input)],
              randomness_seed: rand_seed,
            ),
          ),
        ]
      )
    end
    let(:activation_2) do
      Temporalio::Bridge::Api::WorkflowActivation::WorkflowActivation.new(
        run_id: run_id,
        timestamp: time_2,
        is_replaying: false,
        jobs: [
          Temporalio::Bridge::Api::WorkflowActivation::WorkflowActivationJob.new(
            fire_timer: Temporalio::Bridge::Api::WorkflowActivation::FireTimer.new(seq: 1),
          ),
        ]
      )
    end

    it 'returns output commands' do
      commands = subject.process(activation_1)

      expect(subject).not_to be_finished
      expect(subject).to be_replay
      expect(commands.length).to eq(1)
      expect(commands.first.variant).to eq(:start_timer)
      expect(commands.first.start_timer.seq).to eq(1)
      expect(commands.first.start_timer.start_to_fire_timeout.to_f).to eq(input.to_f)

      commands = subject.process(activation_2)

      expect(subject).to be_finished
      expect(subject).not_to be_replay
      expect(commands.length).to eq(1)
      expect(commands.first.variant).to eq(:complete_workflow_execution)
      expect(converter.from_payload(commands.first.complete_workflow_execution.result))
        .to eq('Slept for 42 seconds')
    end

    it 'sets the time correctly' do
      subject.process(activation_1)
      expect(subject.time).to eq(time_1)

      subject.process(activation_2)
      expect(subject.time).to eq(time_2)
    end

    it 'initializes context correctly' do
      allow(Temporalio::Workflow::Context).to receive(:new).and_call_original

      subject.process(activation_1)

      expect(Temporalio::Workflow::Context).to have_received(:new) do |runner, seed, info, outbound_chain|
        expect(runner).to eq(subject)
        expect(seed).to eq(rand_seed)
        expect(info).to be_a(Temporalio::Workflow::Info)
        expect(info.namespace).to eq(namespace)
        expect(info.parent).to be_a(Temporalio::Workflow::ParentInfo)
        expect(info.parent.namespace).to be_nil
        expect(info.parent.run_id).to be_nil
        expect(info.parent.workflow_id).to be_nil
        expect(info.run_id).to eq(run_id)
        expect(info.task_queue).to eq(task_queue)
        expect(info.workflow_id).to eq(workflow_id)
        expect(info.workflow_type).to eq(workflow_class._name)
        expect(outbound_chain).to be_a(Temporalio::Interceptor::Chain)
      end
    end

    context 'with inbound interceptor' do
      let(:interceptor) { TestInboundWorkflowInterceptor.new }
      let(:inbound_interceptors) { [interceptor] }

      it 'wraps workflow execution' do
        subject.process(activation_1)
        expect(interceptor.output).to eq(%w[before])
        expect(interceptor.input.workflow).to eq(workflow_class)
        expect(interceptor.input.args).to eq([input])
        expect(interceptor.input.headers).to eq({})

        commands = subject.process(activation_2)
        expect(interceptor.output).to eq(%w[before after])

        expect(commands.length).to eq(1)
        expect(commands.first.variant).to eq(:complete_workflow_execution)
        expect(converter.from_payload(commands.first.complete_workflow_execution.result))
          .to eq('Result from interceptor')
      end
    end
  end

  describe '#push_commands' do
    let(:command) do
      Temporalio::Bridge::Api::WorkflowCommands::WorkflowCommand.new(
        start_timer: Temporalio::Bridge::Api::WorkflowCommands::StartTimer.new(
          seq: 1,
          start_to_fire_timeout: Google::Protobuf::Duration.new(seconds: 10),
        ),
      )
    end

    it 'adds command to the array' do
      subject.push_command(command)

      expect(subject.send(:commands)).to eq([command])
    end
  end

  describe '#add_completion' do
    let(:type) { :timer }

    it 'records a completion' do
      resolve = -> {}
      reject = -> {}

      seq_1 = subject.add_completion(type, resolve, reject)
      seq_2 = subject.add_completion(type, resolve, reject)

      expect(seq_1).to eq(1)
      expect(seq_2).to eq(2)
      expect(subject.send(:completions)[type].size).to eq(2)
      expect(subject.send(:completions)[type][seq_1]).to be_a(described_class::Completion)
      expect(subject.send(:completions)[type][seq_1].resolve).to eq(resolve)
      expect(subject.send(:completions)[type][seq_1].reject).to eq(reject)
      expect(subject.send(:completions)[type][seq_2]).to be_a(described_class::Completion)
      expect(subject.send(:completions)[type][seq_2].resolve).to eq(resolve)
      expect(subject.send(:completions)[type][seq_2].reject).to eq(reject)
    end
  end

  describe '#remove_completion' do
    let(:type) { :timer }

    it 'removes completion' do
      seq_1 = subject.add_completion(type, -> {}, -> {})
      seq_2 = subject.add_completion(type, -> {}, -> {})

      expect(subject.remove_completion(type, seq_2)).to eq(true)
      expect(subject.remove_completion(type, seq_1)).to eq(true)

      expect(subject.send(:completions)[type].size).to eq(0)
    end

    it 'returns false when completion is absent' do
      seq = subject.add_completion(type, -> {}, -> {})

      expect(subject.remove_completion(type, 42)).to eq(false)
      expect(subject.remove_completion(type, seq)).to eq(true)
      expect(subject.remove_completion(type, seq)).to eq(false)
    end
  end
end
