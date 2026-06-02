# typed: true

class Temporalio::Internal::Worker::MultiRunner
  extend T::Sig

  sig { params(workers: T::Array[Object], shutdown_signals: T::Array[T.any(String, Integer)]).void }
  def initialize(workers:, shutdown_signals:); end

  sig { params(block: T.nilable(T.proc.returns(Object))).void }
  def apply_thread_or_fiber_block(&block); end

  sig { params(workflow_worker: Temporalio::Internal::Worker::WorkflowWorker, activation: Object).void }
  def apply_workflow_activation_decoded(workflow_worker:, activation:); end

  sig do
    params(
      workflow_worker: Temporalio::Internal::Worker::WorkflowWorker,
      activation_completion: Object,
      encoded: T::Boolean
    ).void
  end
  def apply_workflow_activation_complete(workflow_worker:, activation_completion:, encoded:); end

  sig { params(error: Exception).void }
  def raise_in_thread_or_fiber_block(error); end

  sig { void }
  def initiate_shutdown; end

  sig { void }
  def wait_complete_and_finalize_shutdown; end

  sig { returns(Temporalio::Internal::Worker::MultiRunner::Event) }
  def next_event; end
end

class Temporalio::Internal::Worker::MultiRunner::Event
end

class Temporalio::Internal::Worker::MultiRunner::Event::PollSuccess < Temporalio::Internal::Worker::MultiRunner::Event
  extend T::Sig

  sig { returns(Object) }
  attr_reader :worker

  sig { returns(Symbol) }
  attr_reader :worker_type

  sig { returns(String) }
  attr_reader :bytes

  sig { params(worker: Object, worker_type: Symbol, bytes: String).void }
  def initialize(worker:, worker_type:, bytes:); end
end

class Temporalio::Internal::Worker::MultiRunner::Event::PollFailure < Temporalio::Internal::Worker::MultiRunner::Event
  extend T::Sig

  sig { returns(Object) }
  attr_reader :worker

  sig { returns(Symbol) }
  attr_reader :worker_type

  sig { returns(Exception) }
  attr_reader :error

  sig { params(worker: Object, worker_type: Symbol, error: Exception).void }
  def initialize(worker:, worker_type:, error:); end
end

class Temporalio::Internal::Worker::MultiRunner::Event::WorkflowActivationDecoded < Temporalio::Internal::Worker::MultiRunner::Event
  extend T::Sig

  sig { returns(Temporalio::Internal::Worker::WorkflowWorker) }
  attr_reader :workflow_worker

  sig { returns(Object) }
  attr_reader :activation

  sig { params(workflow_worker: Temporalio::Internal::Worker::WorkflowWorker, activation: Object).void }
  def initialize(workflow_worker:, activation:); end
end

class Temporalio::Internal::Worker::MultiRunner::Event::WorkflowActivationComplete < Temporalio::Internal::Worker::MultiRunner::Event
  extend T::Sig

  sig { returns(Temporalio::Internal::Worker::WorkflowWorker) }
  attr_reader :workflow_worker

  sig { returns(Object) }
  attr_reader :activation_completion

  sig { returns(T::Boolean) }
  attr_reader :encoded

  sig { returns(Queue) }
  attr_reader :completion_complete_queue

  sig do
    params(
      workflow_worker: Temporalio::Internal::Worker::WorkflowWorker,
      activation_completion: Object,
      encoded: T::Boolean,
      completion_complete_queue: Queue
    ).void
  end
  def initialize(workflow_worker:, activation_completion:, encoded:, completion_complete_queue:); end
end

class Temporalio::Internal::Worker::MultiRunner::Event::WorkflowActivationCompletionComplete < Temporalio::Internal::Worker::MultiRunner::Event
  extend T::Sig

  sig { returns(String) }
  attr_reader :run_id

  sig { returns(T.nilable(Exception)) }
  attr_reader :error

  sig { params(run_id: String, error: T.nilable(Exception)).void }
  def initialize(run_id:, error:); end
end

class Temporalio::Internal::Worker::MultiRunner::Event::PollerShutDown < Temporalio::Internal::Worker::MultiRunner::Event
  extend T::Sig

  sig { returns(Object) }
  attr_reader :worker

  sig { returns(Symbol) }
  attr_reader :worker_type

  sig { params(worker: Object, worker_type: Symbol).void }
  def initialize(worker:, worker_type:); end
end

class Temporalio::Internal::Worker::MultiRunner::Event::AllPollersShutDown < Temporalio::Internal::Worker::MultiRunner::Event
  extend T::Sig

  sig { returns(Temporalio::Internal::Worker::MultiRunner::Event::AllPollersShutDown) }
  def self.instance; end
end

class Temporalio::Internal::Worker::MultiRunner::Event::BlockSuccess < Temporalio::Internal::Worker::MultiRunner::Event
  extend T::Sig

  sig { returns(T.nilable(Object)) }
  attr_reader :result

  sig { params(result: T.nilable(Object)).void }
  def initialize(result:); end
end

class Temporalio::Internal::Worker::MultiRunner::Event::BlockFailure < Temporalio::Internal::Worker::MultiRunner::Event
  extend T::Sig

  sig { returns(Exception) }
  attr_reader :error

  sig { params(error: Exception).void }
  def initialize(error:); end
end

class Temporalio::Internal::Worker::MultiRunner::Event::ShutdownSignalReceived < Temporalio::Internal::Worker::MultiRunner::Event
end

class Temporalio::Internal::Worker::MultiRunner::InjectEventForTesting < Temporalio::Error
  extend T::Sig

  sig { returns(Temporalio::Internal::Worker::MultiRunner::Event) }
  attr_reader :event

  sig { params(event: Temporalio::Internal::Worker::MultiRunner::Event).void }
  def initialize(event); end
end
