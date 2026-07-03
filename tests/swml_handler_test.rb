# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Tests for the SWML verb-handler trio (SWMLVerbHandler / AIVerbHandler /
# VerbHandlerRegistry) — build/validate configs and registry round-trips.
class SwmlHandlerTest < Minitest::Test
  def setup
    @handler = SignalWire::SWML::AIVerbHandler.new
  end

  # ---- AIVerbHandler ----

  def test_get_verb_name
    assert_equal 'ai', @handler.get_verb_name
  end

  def test_build_config_text_prompt_wire_keys
    config = @handler.build_config(prompt_text: 'hello')

    # Exact emitted key/value shape — prompt must be an object {"text": ...}.
    assert_equal({ 'text' => 'hello' }, config['prompt'])
    assert_equal({}, config['params'])
  end

  def test_build_config_pom_prompt
    pom = [{ 'title' => 'Role', 'body' => 'assistant' }]
    config = @handler.build_config(prompt_pom: pom)

    assert_equal({ 'pom' => pom }, config['prompt'])
  end

  def test_build_config_routes_top_level_keys
    config = @handler.build_config(
      prompt_text: 'hi', languages: [{ 'code' => 'en' }],
      hints: %w[foo], pronounce: [{ 'x' => 'y' }], global_data: { 'k' => 'v' }
    )

    # languages/hints/pronounce/global_data go to top level.
    assert_equal([{ 'code' => 'en' }], config['languages'])
    assert_equal(%w[foo], config['hints'])
    assert_equal([{ 'x' => 'y' }], config['pronounce'])
    assert_equal({ 'k' => 'v' }, config['global_data'])
  end

  def test_build_config_routes_other_keys_into_params
    config = @handler.build_config(prompt_text: 'hi', temperature: 0.7, top_p: 0.9)

    # Everything not a recognised top-level key goes into params.
    assert_equal({ 'temperature' => 0.7, 'top_p' => 0.9 }, config['params'])
  end

  def test_build_config_post_prompt_and_swaig
    swaig = { 'functions' => [] }
    config = @handler.build_config(
      prompt_text: 'hi',
      post_prompt: 'summarize',
      post_prompt_url: 'https://ex.com/pp',
      swaig: swaig
    )

    assert_equal({ 'text' => 'summarize' }, config['post_prompt'])
    assert_equal 'https://ex.com/pp', config['post_prompt_url']
    assert_equal swaig, config['SWAIG']
  end

  def test_build_config_requires_a_base_prompt
    err = assert_raises(ArgumentError) { @handler.build_config }

    assert_match(/must be provided as base prompt/, err.message)
  end

  def test_build_config_rejects_both_prompts
    err = assert_raises(ArgumentError) do
      @handler.build_config(prompt_text: 'a', prompt_pom: [{ 'x' => 1 }])
    end

    assert_match(/mutually exclusive/, err.message)
  end

  def test_validate_config_valid
    valid, errors = @handler.validate_config({ 'prompt' => { 'text' => 'hi' } })

    assert valid
    assert_empty errors
  end

  def test_validate_config_missing_prompt
    valid, errors = @handler.validate_config({})

    refute valid
    assert_includes errors, "Missing required field 'prompt'"
  end

  def test_validate_config_prompt_not_object
    valid, errors = @handler.validate_config({ 'prompt' => 'a bare string' })

    refute valid
    assert_includes errors, "'prompt' must be an object"
  end

  def test_validate_config_both_text_and_pom
    valid, errors = @handler.validate_config(
      { 'prompt' => { 'text' => 'a', 'pom' => [] } }
    )

    refute valid
    assert(errors.any? { |e| e.include?('mutually exclusive') })
  end

  def test_validate_config_bad_swaig
    valid, errors = @handler.validate_config(
      { 'prompt' => { 'text' => 'a' }, 'SWAIG' => 'nope' }
    )

    refute valid
    assert_includes errors, "'SWAIG' must be an object"
  end
end

# Tests for the SWMLVerbHandler base class and the VerbHandlerRegistry.
class SwmlVerbHandlerRegistryTest < Minitest::Test
  def setup
    @registry = SignalWire::SWML::VerbHandlerRegistry.new
  end

  def test_base_handler_abstract_methods_raise
    base = SignalWire::SWML::SWMLVerbHandler.new

    assert_raises(NotImplementedError) { base.get_verb_name }
    assert_raises(NotImplementedError) { base.validate_config({}) }
    assert_raises(NotImplementedError) { base.build_config }
  end

  def test_registry_registers_ai_by_default
    assert @registry.has_handler('ai')
    assert_instance_of SignalWire::SWML::AIVerbHandler, @registry.get_handler('ai')
  end

  def test_registry_get_missing_returns_nil
    refute @registry.has_handler('nonexistent')
    assert_nil @registry.get_handler('nonexistent')
  end

  def test_registry_register_roundtrip
    custom = Class.new(SignalWire::SWML::SWMLVerbHandler) do
      def get_verb_name = 'custom'
      def validate_config(_config) = [true, []]
      def build_config(**_kwargs) = {}
    end.new

    @registry.register_handler(custom)

    assert @registry.has_handler('custom')
    assert_same custom, @registry.get_handler('custom')
  end
end
