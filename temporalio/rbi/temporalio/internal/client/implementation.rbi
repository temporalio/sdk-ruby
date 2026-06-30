# typed: true

class Temporalio::Internal::Client::Implementation < Temporalio::Client::Interceptor::Outbound
  extend T::Sig

  STANDALONE_ACTIVITY_RESOURCE_ID_PREFIX = T.let(T.unsafe(nil), String)

  sig do
    params(
      ref: Temporalio::Client::ActivityIDReference
    ).returns(T::Hash[Symbol, T.nilable(String)])
  end
  def self._activity_id_reference_request_fields(ref); end

  sig do
    params(
      user_rpc_options: T.nilable(Temporalio::Client::RPCOptions)
    ).returns(Temporalio::Client::RPCOptions)
  end
  def self.with_default_rpc_options(user_rpc_options); end

  sig { params(client: Temporalio::Client).void }
  def initialize(client); end

  sig do
    params(
      klass: Class,
      start_options: Temporalio::Client::WithStartWorkflowOperation::Options
    ).returns(Object)
  end
  def _start_workflow_request_from_with_start_options(klass, start_options); end

  sig { params(input: Temporalio::Client::Interceptor::StartActivityInput).returns(Temporalio::Client::ActivityHandle) }
  def start_activity(input); end

  sig { params(input: Temporalio::Client::Interceptor::DescribeActivityInput).returns(Temporalio::Client::ActivityExecution::Description) }
  def describe_activity(input); end

  sig { params(input: Temporalio::Client::Interceptor::CancelActivityInput).void }
  def cancel_activity(input); end

  sig { params(input: Temporalio::Client::Interceptor::TerminateActivityInput).void }
  def terminate_activity(input); end

  sig { params(input: Temporalio::Client::Interceptor::ListActivitiesInput).returns(T::Enumerator[Temporalio::Client::ActivityExecution]) }
  def list_activities(input); end

  sig { params(input: Temporalio::Client::Interceptor::CountActivitiesInput).returns(Temporalio::Client::ActivityExecutionCount) }
  def count_activities(input); end

  sig { params(input: Temporalio::Client::Interceptor::FetchActivityOutcomeInput).returns(T.nilable(Temporalio::Api::Activity::V1::ActivityExecutionOutcome)) }
  def fetch_activity_outcome(input); end
end
