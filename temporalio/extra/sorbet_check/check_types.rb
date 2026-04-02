# typed: true
# frozen_string_literal: true

# This file validates the enriched RBI types by exercising key SDK API patterns.
# It is checked by `srb tc` in CI — it is never executed at runtime.

require 'sorbet-runtime'
require 'temporalio/activity'
require 'temporalio/client'
require 'temporalio/converters'
require 'temporalio/converters/payload_codec'
require 'temporalio/worker'
require 'temporalio/workflow'

extend T::Sig

# --- Activity definitions ---

class MyActivity < Temporalio::Activity::Definition
  extend T::Sig

  sig { params(name: String).returns(String) }
  def execute(name)
    ctx = Temporalio::Activity::Context.current
    ctx.logger.info("Running activity for #{name}")
    ctx.heartbeat('progress')
    "Hello, #{name}!"
  end
end

# --- Workflow definitions ---

class MyWorkflow < Temporalio::Workflow::Definition
  extend T::Sig

  T::Sig::WithoutRuntime.sig { returns(Temporalio::Workflow::Definition::Query) }
  def self.my_query = T.unsafe(nil)

  T::Sig::WithoutRuntime.sig { returns(Temporalio::Workflow::Definition::Signal) }
  def self.my_signal = T.unsafe(nil)

  T::Sig::WithoutRuntime.sig { returns(Temporalio::Workflow::Definition::Update) }
  def self.my_update = T.unsafe(nil)

  sig { void }
  def initialize
    @value = T.let(nil, T.nilable(String))
    @done = T.let(false, T::Boolean)
  end

  sig { params(name: String).returns(String) }
  def execute(name)
    # Execute activity
    result = T.cast(
      Temporalio::Workflow.execute_activity(MyActivity, name, start_to_close_timeout: 300),
      String
    )

    # Workflow primitives
    Temporalio::Workflow.logger.info("Activity result: #{result}")
    _info = Temporalio::Workflow.info
    _now = Temporalio::Workflow.now

    # Wait with timeout
    begin
      Temporalio::Workflow.timeout(10) do
        Temporalio::Workflow.wait_condition { @done }
      end
    rescue Timeout::Error
      # expected
    end

    result
  end

  workflow_query
  sig { returns(T.nilable(String)) }
  def my_query
    @value
  end

  workflow_signal
  sig { params(value: String).void }
  def my_signal(value)
    @value = value
  end

  workflow_update
  sig { params(value: String).returns(String) }
  def my_update(value)
    old = @value
    @value = value
    old || ''
  end

  workflow_update_validator(:my_update)
  sig { params(value: String).void }
  def validate_my_update(value)
    raise 'empty' if value.empty?
  end
end

# --- Client usage ---

sig { void }
def check_client_types
  client = Temporalio::Client.connect('localhost:7233', 'default')

  # Start workflow
  handle = client.start_workflow(
    MyWorkflow, 'world',
    id: 'test-id', task_queue: 'test-queue'
  )

  # Query, signal, update
  handle.query(MyWorkflow.my_query)
  handle.signal(MyWorkflow.my_signal, 'value')
  handle.execute_update(MyWorkflow.my_update, 'value')

  # Result
  _result = handle.result
end

# --- Worker usage ---

sig { void }
def check_worker_types
  client = Temporalio::Client.connect('localhost:7233', 'default')

  worker = Temporalio::Worker.new(
    client: client,
    task_queue: 'test-queue',
    activities: [MyActivity],
    workflows: [MyWorkflow]
  )

  worker.run(shutdown_signals: ['SIGINT'])
end

# --- Converter/codec usage ---

class MyCodec < Temporalio::Converters::PayloadCodec
  extend T::Sig

  sig { params(payloads: T::Enumerable[T.untyped]).returns(T::Array[T.untyped]) }
  def encode(payloads)
    payloads.map { |p| p }
  end

  sig { params(payloads: T::Enumerable[T.untyped]).returns(T::Array[T.untyped]) }
  def decode(payloads)
    payloads.map { |p| p }
  end
end

sig { void }
def check_converter_types
  codec = MyCodec.new
  converter = Temporalio::Converters::DataConverter.new(payload_codec: codec)
  Temporalio::Client.connect('localhost:7233', 'default', data_converter: converter)
end

# --- Error types ---

sig { void }
def check_error_types
  raise Temporalio::Error::ApplicationError.new('test', non_retryable: true)
rescue Temporalio::Error::ApplicationError => e
  _msg = e.message
  _non_retryable = e.non_retryable
end

# --- Cancellation ---

sig { void }
def check_cancellation_types
  cancellation = Temporalio::Cancellation.new
  _canceled = cancellation.canceled?
  _reason = cancellation.canceled_reason
  cancellation.check!
end

# --- Search attributes ---

sig { void }
def check_search_attributes_types
  key = Temporalio::SearchAttributes::Key.new('my-key', Temporalio::SearchAttributes::IndexedValueType::TEXT)
  update = Temporalio::SearchAttributes::Update.new(key, 'value')
  _k = update.key
  _v = update.value
end

# --- Workflow mutex ---

sig { void }
def check_workflow_mutex_types
  mutex = Temporalio::Workflow::Mutex.new
  mutex.synchronize { 'value' }
end
