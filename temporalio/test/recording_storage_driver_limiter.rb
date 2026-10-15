# frozen_string_literal: true

require 'temporalio/converters/storage_driver_limiter'

# Limiter that runs every operation immediately, recording the items it was asked to permit so tests can assert that
# a driver took a permit per request rather than one around a whole batch.
#
# One instance is shared across whatever concurrency a test drives it with, so its state is guarded.
class RecordingStorageDriverLimiter < Temporalio::Converters::StorageDriverLimiter
  def initialize
    super
    @mutex = Mutex.new
    @items = []
  end

  def items
    @mutex.synchronize { @items.dup }
  end

  def permit(item)
    @mutex.synchronize { @items << item }
    yield
  end
end
