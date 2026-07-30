# typed: true

class Temporalio::Client::ActivityIDReference
  sig { params(workflow_id: String, run_id: T.nilable(String), activity_id: String).void }
  def initialize(workflow_id:, run_id:, activity_id:); end

  sig { params(activity_id: String, activity_run_id: T.nilable(String)).returns(Temporalio::Client::ActivityIDReference) }
  def self.for_standalone(activity_id:, activity_run_id: T.unsafe(nil)); end

  sig { returns(T.nilable(String)) }
  attr_reader :workflow_id

  sig { returns(T.nilable(String)) }
  attr_reader :run_id

  sig { returns(String) }
  attr_reader :activity_id

  sig { returns(T.nilable(String)) }
  attr_reader :activity_run_id

  sig { returns(T::Boolean) }
  def standalone?; end
end
