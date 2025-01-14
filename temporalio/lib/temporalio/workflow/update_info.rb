# frozen_string_literal: true

module Temporalio
  module Workflow
    # Information about a workflow update
    #
    # @!attribute id
    #   @return [String] Update ID.
    # @!attribute name
    #   @return [String] Update name.
    #
    # @note WARNING: This class may have required parameters added to its constructor. Users should not instantiate this
    #   class or it may break in incompatible ways.
    UpdateInfo = Struct.new(
      :id,
      :name,
      keyword_init: true
    )
  end
end
