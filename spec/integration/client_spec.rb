require 'securerandom'
require 'temporal/client'
require 'temporal/connection'

describe Temporal::Client do
  SUPPORT_PATH = 'spec/support'.freeze
  PORT = 5555
  TASK_QUEUE = 'test-client'.freeze
  NAMESPACE = 'ruby-samples'.freeze
  URL = "localhost:#{PORT}".freeze

  subject { described_class.new(connection, NAMESPACE) }

  let(:connection) { Temporal::Connection.new("http://#{URL}") }
  let(:id) { SecureRandom.uuid }

  before(:all) do
    @server_pid = fork { exec("#{SUPPORT_PATH}/go_server/main #{PORT} #{NAMESPACE}") }
    sleep(1) # wait for the server to boot up

    @worker_pid = fork { exec("#{SUPPORT_PATH}/go_worker/main #{URL} #{NAMESPACE} #{TASK_QUEUE}") }
    sleep(1) # wait for the worker to boot up
  end

  after(:all) do
    Process.kill('INT', @worker_pid)
    Process.wait(@worker_pid)
    Process.kill('INT', @server_pid)
    Process.wait(@server_pid)
  end

  describe 'start workflow' do
    let(:workflow) { 'kitchen_sink' }
    let(:input) { { actions: [{ result: { value: 'It works!' } }] } }

    it 'works' do
      handle = subject.start_workflow(workflow, input, id: id, task_queue: TASK_QUEUE)
      expect(handle.result).to eq('It works!')
    end
  end
end
