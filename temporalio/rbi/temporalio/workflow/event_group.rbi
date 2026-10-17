# typed: true

class Temporalio::Workflow::EventGroup
  extend T::Sig

  sig { returns(Temporalio::Workflow::EventGroup::Active) }
  def self._active; end

  sig do
    type_parameters(:T)
      .params(
        active: Temporalio::Workflow::EventGroup::Active,
        block: T.proc.returns(T.type_parameter(:T))
      )
      .returns(T.type_parameter(:T))
  end
  def self._with_active(active, &block); end

  sig do
    type_parameters(:T)
      .params(
        groups: Temporalio::Workflow::EventGroup,
        block: T.proc.returns(T.type_parameter(:T))
      )
      .returns(T.type_parameter(:T))
  end
  def self._with_event_groups(*groups, &block); end

  sig do
    type_parameters(:T)
      .params(event_id: Integer, block: T.proc.returns(T.type_parameter(:T)))
      .returns(T.type_parameter(:T))
  end
  def self._with_inbound_event(event_id, &block); end

  sig do
    type_parameters(:T)
      .params(update_id: String, block: T.proc.returns(T.type_parameter(:T)))
      .returns(T.type_parameter(:T))
  end
  def self._with_inbound_update(update_id, &block); end

  sig do
    params(directs: T.nilable(T::Array[Temporalio::Workflow::EventGroup]))
      .returns(T::Array[Temporalio::Api::Sdk::V1::EventGroupMarker])
  end
  def self._markers_for_command(directs); end

  sig { void }
  def initialize; end

  sig do
    params(_active: Temporalio::Workflow::EventGroup::Active)
      .returns(Temporalio::Workflow::EventGroup::Active)
  end
  def _applied_over(_active); end

  sig { returns(Temporalio::Api::Sdk::V1::EventGroupMarker) }
  def _to_proto; end
end

class Temporalio::Workflow::EventGroup::Active
  extend T::Sig

  sig { returns(T.nilable(Temporalio::Workflow::EventGroup)) }
  def implicit; end

  sig { params(_: T.nilable(Temporalio::Workflow::EventGroup)).void }
  def implicit=(_); end

  sig { returns(T::Hash[String, Temporalio::Workflow::EventGroup]) }
  def explicit; end

  sig { params(_: T::Hash[String, Temporalio::Workflow::EventGroup]).void }
  def explicit=(_); end

  sig do
    params(
      implicit: T.nilable(Temporalio::Workflow::EventGroup),
      explicit: T::Hash[String, Temporalio::Workflow::EventGroup]
    ).void
  end
  def initialize(implicit: nil, explicit: {}); end
end

class Temporalio::Workflow::EventGroup::Label < Temporalio::Workflow::EventGroup
  extend T::Sig

  sig { returns(String) }
  attr_reader :id

  sig { returns(T.nilable(String)) }
  attr_reader :label

  sig { params(id: String, label: T.nilable(String)).void }
  def initialize(id, label); end
end

class Temporalio::Workflow::EventGroup::Implicit < Temporalio::Workflow::EventGroup
  extend T::Sig

  sig { params(marker: Temporalio::Api::Sdk::V1::EventGroupMarker).void }
  def initialize(marker); end
end
