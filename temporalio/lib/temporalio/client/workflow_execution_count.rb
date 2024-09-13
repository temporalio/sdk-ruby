# frozen_string_literal: true

module Temporalio
  class Client
    # Representation of a count from a count workflows call.
    class WorkflowExecutionCount
      # @return [Integer] Approximate number of workflows matching the original query. If the query had a group-by
      # clause, this is simply the sum of all the counts in {groups}.
      attr_reader :count

      # @return [Array<AggregationGroup>] Groups if the query had a group-by clause, or empty if not.
      attr_reader :groups

      # @!visibility private
      def initialize(count, groups)
        @count = count
        @groups = groups
      end

      # Aggregation group if the workflow count query had a group-by clause.
      class AggregationGroup
        # @return [Integer] Approximate number of workflows matching the original query for this group.
        attr_reader :count

        # @return [Array<Object>] Search attribute values for this group.
        attr_reader :group_values

        # @!visibility private
        def initialize(count, group_values)
          @count = count
          @group_values = group_values
        end
      end
    end
  end
end
