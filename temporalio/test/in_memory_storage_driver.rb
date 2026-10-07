# frozen_string_literal: true

require 'temporalio/api'
require 'temporalio/converters/storage_driver'
require 'temporalio/converters/storage_driver_claim'

# Storage driver that keeps payloads in a hash, recording what it was asked to do so tests can assert on batching
# and targets.
class InMemoryStorageDriver < Temporalio::Converters::StorageDriver
  attr_reader :stored, :store_calls, :retrieve_calls, :name, :type

  def initialize(name: 'mem', type: 'test.memdriver')
    super()
    @name = name
    @type = type
    @stored = {}
    @store_calls = []
    @retrieve_calls = []
  end

  def store(context, payloads)
    @store_calls << [context, payloads.size]
    payloads.map do |payload|
      key = SecureRandom.uuid
      @stored[key] = payload.to_proto
      Temporalio::Converters::StorageDriverClaim.new(claim_data: { 'key' => key })
    end
  end

  def retrieve(_context, claims)
    @retrieve_calls << claims.size
    claims.map do |claim|
      bytes = @stored.fetch(claim.claim_data.fetch('key'))
      Temporalio::Api::Common::V1::Payload.decode(bytes)
    end
  end
end
