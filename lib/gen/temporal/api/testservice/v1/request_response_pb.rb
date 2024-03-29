# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: temporal/api/testservice/v1/request_response.proto

require 'google/protobuf'

require 'google/protobuf/duration_pb'
require 'google/protobuf/timestamp_pb'
require 'dependencies/gogoproto/gogo_pb'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_file("temporal/api/testservice/v1/request_response.proto", :syntax => :proto3) do
    add_message "temporal.api.testservice.v1.LockTimeSkippingRequest" do
    end
    add_message "temporal.api.testservice.v1.LockTimeSkippingResponse" do
    end
    add_message "temporal.api.testservice.v1.UnlockTimeSkippingRequest" do
    end
    add_message "temporal.api.testservice.v1.UnlockTimeSkippingResponse" do
    end
    add_message "temporal.api.testservice.v1.SleepUntilRequest" do
      optional :timestamp, :message, 1, "google.protobuf.Timestamp"
    end
    add_message "temporal.api.testservice.v1.SleepRequest" do
      optional :duration, :message, 1, "google.protobuf.Duration"
    end
    add_message "temporal.api.testservice.v1.SleepResponse" do
    end
    add_message "temporal.api.testservice.v1.GetCurrentTimeResponse" do
      optional :time, :message, 1, "google.protobuf.Timestamp"
    end
  end
end

module Temporalio
  module Api
    module TestService
      module V1
        LockTimeSkippingRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.testservice.v1.LockTimeSkippingRequest").msgclass
        LockTimeSkippingResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.testservice.v1.LockTimeSkippingResponse").msgclass
        UnlockTimeSkippingRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.testservice.v1.UnlockTimeSkippingRequest").msgclass
        UnlockTimeSkippingResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.testservice.v1.UnlockTimeSkippingResponse").msgclass
        SleepUntilRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.testservice.v1.SleepUntilRequest").msgclass
        SleepRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.testservice.v1.SleepRequest").msgclass
        SleepResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.testservice.v1.SleepResponse").msgclass
        GetCurrentTimeResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("temporal.api.testservice.v1.GetCurrentTimeResponse").msgclass
      end
    end
  end
end
