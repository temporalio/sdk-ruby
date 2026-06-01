# frozen_string_literal: true

require 'minitest/autorun'
require 'pathname'

class TypeSignatureCoverageTest < Minitest::Test
  ROOT = Pathname.new(File.expand_path('..', __dir__))
  LIB_ROOT = ROOT.join('lib')
  RBI_ROOT = ROOT.join('rbi')
  SIG_ROOT = ROOT.join('sig')

  KNOWN_MISSING_RBS = %w[
    temporalio/api/cloud/cloudservice
    temporalio/api/operatorservice
    temporalio/api/workflowservice
    temporalio/converters
    temporalio/internal
    temporalio/internal/bridge/api
  ].freeze

  KNOWN_MISSING_RBI = %w[
    temporalio/api/cloud/cloudservice
    temporalio/api/operatorservice
    temporalio/api/payload_visitor
    temporalio/api/workflowservice
    temporalio/internal
    temporalio/internal/bridge
    temporalio/internal/bridge/api
    temporalio/internal/bridge/api/activity_result/activity_result
    temporalio/internal/bridge/api/activity_task/activity_task
    temporalio/internal/bridge/api/child_workflow/child_workflow
    temporalio/internal/bridge/api/common/common
    temporalio/internal/bridge/api/core_interface
    temporalio/internal/bridge/api/external_data/external_data
    temporalio/internal/bridge/api/nexus/nexus
    temporalio/internal/bridge/api/workflow_activation/workflow_activation
    temporalio/internal/bridge/api/workflow_commands/workflow_commands
    temporalio/internal/bridge/api/workflow_completion/workflow_completion
    temporalio/internal/bridge/client
    temporalio/internal/bridge/runtime
    temporalio/internal/bridge/testing
    temporalio/internal/bridge/worker
    temporalio/internal/client/implementation
    temporalio/internal/metric
    temporalio/internal/proto_utils
    temporalio/internal/worker/activity_worker
    temporalio/internal/worker/multi_runner
    temporalio/internal/worker/workflow_instance
    temporalio/internal/worker/workflow_instance/child_workflow_handle
    temporalio/internal/worker/workflow_instance/context
    temporalio/internal/worker/workflow_instance/details
    temporalio/internal/worker/workflow_instance/external_workflow_handle
    temporalio/internal/worker/workflow_instance/externally_immutable_hash
    temporalio/internal/worker/workflow_instance/handler_execution
    temporalio/internal/worker/workflow_instance/handler_hash
    temporalio/internal/worker/workflow_instance/illegal_call_tracer
    temporalio/internal/worker/workflow_instance/inbound_implementation
    temporalio/internal/worker/workflow_instance/nexus_client
    temporalio/internal/worker/workflow_instance/nexus_operation_handle
    temporalio/internal/worker/workflow_instance/outbound_implementation
    temporalio/internal/worker/workflow_instance/replay_safe_logger
    temporalio/internal/worker/workflow_instance/replay_safe_metric
    temporalio/internal/worker/workflow_instance/scheduler
    temporalio/internal/worker/workflow_worker
    temporalio/version
  ].freeze

  def test_ruby_files_have_matching_rbs_files
    assert_no_unexpected_missing_files(
      'RBS',
      missing_signature_paths(SIG_ROOT, '.rbs'),
      KNOWN_MISSING_RBS
    )
  end

  def test_ruby_files_have_matching_rbi_files
    assert_no_unexpected_missing_files(
      'RBI',
      missing_signature_paths(RBI_ROOT, '.rbi'),
      KNOWN_MISSING_RBI
    )
  end

  private

  def ruby_paths
    @ruby_paths ||= relative_stems(LIB_ROOT, '**/*.rb')
  end

  def missing_signature_paths(root, extension)
    ruby_paths - relative_stems(root, "**/*#{extension}")
  end

  def relative_stems(root, pattern)
    Dir.glob(root.join(pattern).to_s).map do |path|
      Pathname.new(path).relative_path_from(root).sub_ext('').to_s
    end.sort
  end

  def assert_no_unexpected_missing_files(kind, missing_paths, known_missing_paths)
    unexpected_missing = missing_paths - known_missing_paths
    assert_empty unexpected_missing, "Ruby files missing #{kind} files:\n#{unexpected_missing.join("\n")}"

    fixed = known_missing_paths - missing_paths
    assert_empty fixed, "Known missing #{kind} files now exist. Remove from allowlist:\n#{fixed.join("\n")}"
  end
end
