# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Tests for SignalWire::Core::Agent::Tools::TypeInference — the SWAIG
# schema-inference module functions (infer_schema, create_typed_handler_wrapper).
class ToolTypeInferenceTest < Minitest::Test
  TI = SignalWire::Core::Agent::Tools::TypeInference

  # A typed handler with a required keyword, an optional keyword, and the
  # raw_data channel.
  def typed_handler
    ->(city:, days: 3, raw_data: nil) { "#{city}/#{days}/#{raw_data}" }
  end

  def test_infer_schema_from_keyword_params
    params, required, desc, is_typed, has_raw = TI.infer_schema(typed_handler)

    assert_equal %w[city days], params.keys.sort
    assert_equal 'string', params['city']['type']
    assert_equal ['city'], required, 'city is required (no default); days has a default'
    assert_nil desc
    assert is_typed
    assert has_raw, 'raw_data param detected'
  end

  def test_raw_data_excluded_from_schema
    params, = TI.infer_schema(typed_handler)

    refute params.key?('raw_data')
  end

  def test_type_override_map
    handler = ->(count:, ratio: 1.0) {}
    params, = TI.infer_schema(handler, types: { count: Integer, ratio: 'number' })

    assert_equal 'integer', params['count']['type']
    assert_equal 'number', params['ratio']['type']
  end

  def test_descriptions_map
    handler = ->(city:) {}
    params, = TI.infer_schema(handler, descriptions: { city: 'The target city' })

    assert_equal 'The target city', params['city']['description']
  end

  def test_positional_required_and_optional
    handler = ->(a, b = 2) {}
    params, required, = TI.infer_schema(handler)

    assert_equal %w[a b], params.keys.sort
    assert_equal ['a'], required
  end

  def test_legacy_args_handler_is_not_typed
    params, required, desc, is_typed, has_raw = TI.infer_schema(->(args) {})

    assert_empty params
    assert_empty required
    assert_nil desc
    refute is_typed
    refute has_raw
  end

  def test_legacy_args_raw_data_handler_is_not_typed
    _params, _required, _desc, is_typed, = TI.infer_schema(->(args, raw_data) {})

    refute is_typed
  end

  def test_splat_handler_falls_back_to_untyped
    _params, _required, _desc, is_typed, = TI.infer_schema(->(**kwargs) {})

    refute is_typed
  end

  def test_zero_param_handler_is_typed
    params, required, _desc, is_typed, has_raw = TI.infer_schema(-> {})

    assert_empty params
    assert_empty required
    assert is_typed
    refute has_raw
  end

  def test_only_raw_data_handler_is_typed_with_raw
    params, _required, _desc, is_typed, has_raw = TI.infer_schema(->(raw_data:) {})

    assert_empty params
    assert is_typed
    assert has_raw
  end

  def test_wrapper_explodes_args_into_keywords
    wrapper = TI.create_typed_handler_wrapper(->(city:, days: 1) { "#{city}-#{days}" }, false)

    assert_equal 'NYC-5', wrapper.call({ 'city' => 'NYC', 'days' => 5 }, nil)
  end

  def test_wrapper_passes_raw_data_when_declared
    wrapper = TI.create_typed_handler_wrapper(
      ->(city:, raw_data:) { "#{city}/#{raw_data['id']}" }, true
    )

    assert_equal 'NYC/7', wrapper.call({ 'city' => 'NYC' }, { 'id' => 7 })
  end

  def test_wrapper_handles_symbol_keyed_args
    wrapper = TI.create_typed_handler_wrapper(->(city:) { city }, false)

    assert_equal 'LA', wrapper.call({ city: 'LA' }, nil)
  end
end
