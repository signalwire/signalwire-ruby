# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Shared SWAIGFunction fixture factory.
module SwaigFunctionFixture
  def build_function(**overrides)
    defaults = {
      name: 'get_weather',
      description: 'Get the current weather for a city',
      handler: ->(args, _raw) { SignalWire::Swaig::FunctionResult.new("Weather in #{args['city']}") },
      parameters: { 'city' => { 'type' => 'string' } },
      required: ['city']
    }
    SignalWire::Swaig::SWAIGFunction.new(**defaults, **overrides)
  end
end

# Tests for SWAIGFunction construction, #call, and #execute.
class SwaigFunctionTest < Minitest::Test
  include SwaigFunctionFixture

  def test_initialize_attributes
    fn = build_function(webhook_url: 'https://ex.com/hook', secure: true)

    assert_equal 'get_weather', fn.name
    assert_equal 'Get the current weather for a city', fn.description
    assert fn.secure
    assert fn.is_external
    assert_equal 'https://ex.com/hook', fn.webhook_url
  end

  def test_not_external_without_webhook
    refute build_function.is_external
  end

  def test_extra_swaig_fields_stringified
    fn = build_function(meta_data_token: 'tok', web_hook_auth_user: 'u')

    assert_equal 'tok', fn.extra_swaig_fields['meta_data_token']
    assert_equal 'u', fn.extra_swaig_fields['web_hook_auth_user']
  end

  # ---- call (Ruby analog of Python __call__) ----

  def test_call_invokes_handler
    fn = build_function
    result = fn.call({ 'city' => 'NYC' }, {})

    assert_instance_of SignalWire::Swaig::FunctionResult, result
    assert_equal 'Weather in NYC', result.response
  end

  # ---- execute ----

  def test_execute_function_result_to_hash
    fn = build_function
    out = fn.execute({ 'city' => 'LA' })

    assert_equal 'Weather in LA', out['response']
  end

  def test_execute_passthrough_response_hash
    fn = build_function(handler: ->(_a, _r) { { 'response' => 'raw' } })

    assert_equal({ 'response' => 'raw' }, fn.execute({}))
  end

  def test_execute_dict_without_response
    fn = build_function(handler: ->(_a, _r) { { 'other' => 1 } })
    out = fn.execute({})

    assert_equal 'Function completed successfully', out['response']
  end

  def test_execute_string_result
    fn = build_function(handler: ->(_a, _r) { 'plain string' })

    assert_equal 'plain string', fn.execute({})['response']
  end

  def test_execute_swallows_handler_errors
    fn = build_function(handler: ->(_a, _r) { raise 'boom' })
    out = fn.execute({ 'city' => 'X' })

    # Error is swallowed; a generic, non-leaking message is returned.
    assert_match(/couldn't complete that action/, out['response'])
  end
end

# Tests for SWAIGFunction#to_swaig and #validate_args.
class SwaigFunctionSerializationTest < Minitest::Test
  include SwaigFunctionFixture

  def test_to_swaig_wire_shape
    fn = build_function
    swaig = fn.to_swaig(base_url: 'https://ex.com')

    assert_equal 'get_weather', swaig['function']
    assert_equal 'Get the current weather for a city', swaig['description']
    assert_equal 'https://ex.com/swaig', swaig['web_hook_url']
    # parameters wrapped into the {type, properties, required} envelope.
    assert_equal(
      { 'type' => 'object', 'properties' => { 'city' => { 'type' => 'string' } }, 'required' => ['city'] },
      swaig['parameters']
    )
  end

  def test_to_swaig_with_token_and_call_id
    fn = build_function
    swaig = fn.to_swaig(base_url: 'https://ex.com', token: 'T', call_id: 'C')

    assert_equal 'https://ex.com/swaig?token=T&call_id=C', swaig['web_hook_url']
  end

  def test_to_swaig_includes_fillers_and_extras
    fn = build_function(fillers: { 'en-US' => ['one moment'] }, meta_data_token: 'tok')
    swaig = fn.to_swaig(base_url: 'https://ex.com')

    assert_equal({ 'en-US' => ['one moment'] }, swaig['fillers'])
    assert_equal 'tok', swaig['meta_data_token']
  end

  def test_to_swaig_preexisting_structured_parameters_untouched
    schema = { 'type' => 'object', 'properties' => { 'q' => { 'type' => 'string' } }, 'required' => ['q'] }
    fn = build_function(parameters: schema, required: [])
    swaig = fn.to_swaig(base_url: 'https://ex.com')

    assert_equal schema, swaig['parameters']
  end

  # ---- validate_args ----

  def test_validate_args_accepts_valid
    valid, errors = build_function.validate_args({ 'city' => 'NYC' })

    assert valid
    assert_empty errors
  end

  def test_validate_args_rejects_missing_required
    valid, errors = build_function.validate_args({})

    refute valid
    assert(errors.any? { |e| e.include?('city') })
  end

  def test_validate_args_rejects_wrong_type
    valid, errors = build_function.validate_args({ 'city' => 123 })

    refute valid
    assert(errors.any? { |e| e.include?('string') })
  end

  def test_validate_args_no_params_is_valid
    fn = build_function(parameters: {}, required: [])
    valid, errors = fn.validate_args({})

    assert valid
    assert_empty errors
  end
end
