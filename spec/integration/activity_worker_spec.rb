require 'support/helpers/test_rpc'
require 'temporal/activity'
require 'temporal/bridge'
require 'temporal/client'
require 'temporal/worker'

class HelloWorldActivity < Temporal::Activity
  activity_name 'echo-activity'

  def execute(name)
    "Hello, #{name}!"
  end
end

describe Temporal::Worker::ActivityWorker do
  support_path = 'spec/support'.freeze
  port = 5555
  task_queue = 'test-worker'.freeze
  activity_task_queue = 'test-activity-worker'.freeze
  namespace = 'ruby-samples'.freeze
  url = "localhost:#{port}".freeze

  subject do
    Temporal::Worker.new(
      connection,
      namespace,
      activity_task_queue,
      activities: [HelloWorldActivity],
    )
  end

  let(:client) { Temporal::Client.new(connection, namespace) }
  let(:connection) { Temporal::Connection.new(url) }
  let(:id) { SecureRandom.uuid }
  let(:workflow) { 'kitchen_sink' }

  before(:all) do
    Temporal::Bridge.init_telemetry

    @server_pid = fork { exec("#{support_path}/go_server/main #{port} #{namespace}") }
    Helpers::TestRPC.wait(url, 10, 0.5)

    @worker_pid = fork { exec("#{support_path}/go_worker/main #{url} #{namespace} #{task_queue}") }
  end

  after(:all) do
    Process.kill('INT', @worker_pid)
    Process.wait(@worker_pid)
    Process.kill('INT', @server_pid)
    Process.wait(@server_pid)
  end

  describe 'running an activity' do
    before { subject.start }
    after { subject.shutdown }

    it 'runs an activity and returns a result' do
      input = {
        actions: [{
          execute_activity: {
            name: 'echo-activity',
            task_queue: activity_task_queue,
            args: ['test'],
          },
        }],
      }
      handle = client.start_workflow(workflow, input, id: id, task_queue: task_queue)

      expect(handle.result).to eq('Hello, test!')
    end
  end
end
