# frozen_string_literal: true

require 'async'
require 'temporalio/client'
require 'temporalio/testing'
require 'test_helper'

class ClientTest < Minitest::Test
  include TestHelper

  def test_version_number
    assert !Temporalio::VERSION.nil?
  end

  def test_start_workflows_threaded
    start_workflows
  end

  def test_start_workflows_async
    Sync do
      start_workflows
    end
  end

  def start_workflows
    # Create ephemeral test server
    env.with_kitchen_sink_worker do |task_queue|
      # Start 5 workflows
      handles = 5.times.map do |i|
        env.client.start_workflow(
          'kitchen_sink',
          { actions: [{ result: { value: "result-#{i}" } }] },
          id: "wf-#{SecureRandom.uuid}",
          task_queue:
        )
      end
      # Check all results
      results = handles.map(&:result)
      assert_equal %w[result-0 result-1 result-2 result-3 result-4], results
    end
  end
end

# TODO(cretz):
# * All client options
# * Cloud tests
# * Test splatting options
