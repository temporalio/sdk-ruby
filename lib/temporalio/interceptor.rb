require 'temporalio/interceptor/activity_inbound'
require 'temporalio/interceptor/activity_outbound'
require 'temporalio/interceptor/workflow_inbound'
require 'temporalio/interceptor/workflow_outbound'

module Temporalio
  module Interceptor
    # NOTE: Using #each_with_object here and below instead of a simple #select because RBS can't
    #       reconcile that resulting array only has WorkflowInbound or WorkflowOutbound in it.
    def self.filter(interceptors, type)
      interceptor_class =
        case type
        when :activity_inbound
          Temporalio::Interceptor::ActivityInbound
        when :activity_outbound
          Temporalio::Interceptor::ActivityOutbound
        when :workflow_inbound
          Temporalio::Interceptor::WorkflowInbound
        when :workflow_outbound
          Temporalio::Interceptor::WorkflowOutbound
        end

      interceptors.each_with_object([]) do |i, result|
        result << i if i.is_a?(interceptor_class)
      end
    end
  end
end
