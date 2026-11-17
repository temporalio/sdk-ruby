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
  attr_reader :name, :type

  # @param delay [Float] Seconds each store and retrieve sleeps, so tests can assert a lower bound on measured time.
  def initialize(name: 'mem', type: 'test.memdriver', delay: 0)
    super()
    @name = name
    @type = type
    @delay = delay
    @mutex = Mutex.new
    @stored = {}
    @store_calls = []
    @retrieve_calls = []
  end

  def stored
    @mutex.synchronize { @stored.dup }
  end

  def store_calls
    @mutex.synchronize { @store_calls.dup }
  end

  def retrieve_calls
    @mutex.synchronize { @retrieve_calls.dup }
  end

  def store(context, payloads)
    @mutex.synchronize { @store_calls << [context, payloads.size] }
    sleep(@delay) if @delay.positive?
    payloads.map do |payload|
      key = SecureRandom.uuid
      @mutex.synchronize { @stored[key] = payload.to_proto }
      Temporalio::Converters::StorageDriverClaim.new(claim_data: { 'key' => key })
    end
  end

  def retrieve(_context, claims)
    @mutex.synchronize { @retrieve_calls << claims.size }
    sleep(@delay) if @delay.positive?
    claims.map do |claim|
      bytes = @mutex.synchronize { @stored.fetch(claim.claim_data.fetch('key')) }
      Temporalio::Api::Common::V1::Payload.decode(bytes)
    end
  end
end
