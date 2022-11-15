require 'temporal/connection'

module Helpers
  module TestRPC
    def self.wait(address, max_attempts, interval = 1)
      request = Temporal::Api::WorkflowService::V1::GetSystemInfoRequest.new
      max_attempts.times do |i|
        connection = Temporal::Connection.new(address)
        connection.get_system_info(request)
        break
      rescue StandardError => e
        puts "Error connecting to a server: #{e}. Attempt #{i + 1} / #{max_attempts}"
        raise if i + 1 == max_attempts # re-raise upon exhausting attempts

        sleep interval
      end
    end
  end
end
