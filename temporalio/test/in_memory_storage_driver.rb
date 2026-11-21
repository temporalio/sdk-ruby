# frozen_string_literal: true

require 'securerandom'
require 'temporalio/api'
require 'temporalio/converters/storage_driver'
require 'temporalio/converters/storage_driver_claim'

# Storage driver that keeps payloads in a hash, recording what it was asked to do so tests can assert on batching
# and targets.
#
# One instance is shared across whatever concurrency a test drives it with, so all of its state is guarded and the
# readers hand back snapshots rather than the live collections.
class InMemoryStorageDriver < Temporalio::Converters::StorageDriver
  StoredPayload = Data.define(:target, :namespace, :payload)

  attr_reader :name, :type

  def initialize(name: 'mem', type: 'test.memdriver')
    super()
    @name = name
    @type = type
    @mutex = Mutex.new
    @stored = {}
    @store_calls = []
    @stored_payloads = []
    @retrieve_calls = []
  end

  def stored
    @mutex.synchronize { @stored.dup }
  end

  def store_calls
    @mutex.synchronize { @store_calls.dup }
  end

  def targets_of_payloads_with_data(data)
    stored_payloads_with_data(data).map(&:target)
  end

  def namespaces_of_payloads_with_data(data)
    stored_payloads_with_data(data).map(&:namespace)
  end

  def retrieve_calls
    @mutex.synchronize { @retrieve_calls.dup }
  end

  def store(context, payloads)
    @mutex.synchronize do
      @store_calls << [context, payloads.count]
      payloads.each do |payload|
        @stored_payloads << StoredPayload.new(target: context.target, namespace: context.namespace, payload:)
      end
    end
    payloads.map do |payload|
      key = SecureRandom.uuid
      @mutex.synchronize { @stored[key] = payload.to_proto }
      Temporalio::Converters::StorageDriverClaim.new(claim_data: { 'key' => key })
    end
  end

  def retrieve(_context, claims)
    @mutex.synchronize { @retrieve_calls << claims.count }
    claims.map do |claim|
      bytes = @mutex.synchronize { @stored.fetch(claim.claim_data.fetch('key')) }
      Temporalio::Api::Common::V1::Payload.decode(bytes)
    end
  end

  private

  def stored_payloads_with_data(data)
    @mutex.synchronize { @stored_payloads.select { |stored_payload| stored_payload.payload.data == data } }
  end
end
