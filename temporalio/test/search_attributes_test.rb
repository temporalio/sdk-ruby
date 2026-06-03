# frozen_string_literal: true

require 'test'

class SearchAttributesTest < Test
  def test_keyword_list_null_set_value_rejected
    assert_raises(ArgumentError) { ATTR_KEY_KEYWORD_LIST.value_set(nil) }
  end

  def test_keyword_list_null_element_rejected
    assert_raises(TypeError) { ATTR_KEY_KEYWORD_LIST.value_set(['keyword', nil]) }
  end

  def test_keyword_list_unset_serializes_without_type_metadata
    _name, payload = ATTR_KEY_KEYWORD_LIST.value_unset._to_proto_pair

    assert_equal 'binary/null', payload.metadata['encoding']
    assert_nil payload.metadata['type']
  end

  def test_keyword_list_null_payload_decodes_as_absent
    [json_null_payload(false), binary_null_payload(true), json_null_payload(true)].each do |payload|
      attrs = Temporalio::SearchAttributes._from_proto(
        Temporalio::Api::Common::V1::SearchAttributes.new(
          indexed_fields: { ATTR_KEY_KEYWORD_LIST.name => payload }
        ),
        never_nil: true
      )

      assert_empty attrs
      refute attrs.to_h.key?(ATTR_KEY_KEYWORD_LIST)
    end
  end

  private

  def binary_null_payload(with_type)
    metadata = { 'encoding' => 'binary/null' }
    metadata['type'] = 'KeywordList' if with_type
    Temporalio::Api::Common::V1::Payload.new(metadata:)
  end

  def json_null_payload(with_type)
    metadata = { 'encoding' => 'json/plain' }
    metadata['type'] = 'KeywordList' if with_type
    Temporalio::Api::Common::V1::Payload.new(metadata:, data: 'null')
  end
end
