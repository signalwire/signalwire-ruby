# frozen_string_literal: true

# Copyright (c) 2025 SignalWire
#
# Licensed under the MIT License.
# See LICENSE file in the project root for full license information.

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# SWML strict-render contract (Wave-2 P#5), ported from the python reference
# tests/unit/core/test_swml_strict_render.py.
#
# Building / rendering an SWML document with a MISSHAPEN config, an UNKNOWN
# verb, or a MISSPELLED key must RAISE a clear error — not silently drop or
# accept it. Most of the contract is enforced at the +add_verb+ choke point via
# full JSON-Schema validation (unknown verb, misspelled/unknown keys on closed
# verbs, wrong-typed config). Two gaps this suite pins:
#
#   GAP 1 — the +ai+ verb's specialized AIVerbHandler validated only
#   prompt/SWAIG shape, so it silently accepted unknown/misspelled top-level ai
#   keys (temperatur, zzz) that every schema-validated verb rejects. The ai
#   object schema is closed (unevaluatedProperties disallows extras); the
#   handler simply wasn't consulting it. ai.params stays intentionally open.
#
#   GAP 2 — ContextBuilder#validate! checked dangling valid_steps/valid_contexts
#   references but NOT a step's set_functions([...]) whitelist against the
#   agent's registered SWAIG tools + reserved native tools. A step whitelisting
#   a nonexistent function rendered a dangling reference silently.
class SwmlStrictRenderTest < Minitest::Test
  ValidationError = SignalWire::Utils::SchemaValidationError

  def strict_service
    SignalWire::SWML::Service.new(name: 'strict', route: '/strict', schema_validation: true)
  end

  def strict_agent
    SignalWire::AgentBase.new(name: 'ctxagent', route: '/ctx', schema_validation: true)
  end

  # -------------------------------------------------------------------------
  # Baseline: unknown verb + good verb (regression guards).
  # -------------------------------------------------------------------------

  def test_unknown_verb_raises
    err = assert_raises(ValidationError) { strict_service.add_verb('foobar', {}) }
    assert_includes err.message, 'foobar'
  end

  def test_good_verb_renders
    assert_equal true, strict_service.add_verb('answer', { 'max_duration' => 5 })
  end

  # -------------------------------------------------------------------------
  # Misspelled / unknown / wrong-typed keys on closed verbs.
  # -------------------------------------------------------------------------

  # verb, config pairs whose bad key/type the closed-verb schema must reject.
  MISSHAPEN_VERB_CONFIGS = [
    ['answer', { 'maxduration' => 5 }],            # misspelled max_duration
    ['answer', { 'wibble' => 1 }],                 # unknown key
    ['play',   { 'urlz' => ['say:hi'] }],          # misspelled urls
    ['play',   { 'url' => 'say:hi', 'foo' => 1 }], # valid + unknown extra
    ['record', { 'formatt' => 'wav' }]             # misspelled format
  ].freeze

  def test_misspelled_or_unknown_key_raises
    MISSHAPEN_VERB_CONFIGS.each do |verb, config|
      assert_raises(ValidationError, "expected #{verb} #{config.inspect} to raise") do
        strict_service.add_verb(verb, config)
      end
    end
  end

  def test_wrong_typed_config_raises
    assert_raises(ValidationError) do
      strict_service.add_verb('answer', { 'max_duration' => 'notanumber' })
    end
  end

  # -------------------------------------------------------------------------
  # GAP 1 — the ai verb rejects unknown/misspelled top-level keys, ai.params open.
  # -------------------------------------------------------------------------

  def test_ai_good_config_renders
    assert_equal true, strict_service.add_verb('ai', { 'prompt' => { 'text' => 'hi' } })
  end

  def test_ai_good_config_with_swaig_renders
    ok = strict_service.add_verb('ai', { 'prompt' => { 'text' => 'hi' }, 'SWAIG' => { 'functions' => [] } })

    assert_equal true, ok
  end

  def test_ai_misspelled_top_level_key_raises
    assert_raises(ValidationError) do
      strict_service.add_verb('ai', { 'prompt' => { 'text' => 'hi' }, 'temperatur' => 0.5 })
    end
  end

  def test_ai_unknown_top_level_key_raises
    assert_raises(ValidationError) do
      strict_service.add_verb('ai', { 'prompt' => { 'text' => 'hi' }, 'zzz' => 1 })
    end
  end

  def test_ai_missing_prompt_still_raises
    # The handler's own prompt check must survive alongside the schema pass.
    assert_raises(ValidationError) do
      strict_service.add_verb('ai', { 'post_prompt' => { 'text' => 'bye' } })
    end
  end

  def test_ai_params_subobject_stays_open
    # params is the deliberate open door for LLM tuning params; a key inside it
    # is NOT a misspelling and must render.
    ok = strict_service.add_verb('ai', { 'prompt' => { 'text' => 'hi' }, 'params' => { 'some_future_param' => 1 } })

    assert_equal true, ok
  end

  # -------------------------------------------------------------------------
  # GAP 2 — dangling step set_functions reference.
  # -------------------------------------------------------------------------

  def test_dangling_function_ref_raises
    agent = strict_agent
    agent.define_tool(name: 'order_status', description: 'look up an order', parameters: {}, handler: nil) do |_a, _r|
      nil
    end
    contexts = agent.define_contexts
    step = contexts.add_context('default').add_step('help')
    step.set_text('help the caller')
    step.set_functions(%w[order_status get_datetime]) # get_datetime dangles

    err = assert_raises(ArgumentError) { contexts.to_h }
    assert_includes err.message, 'get_datetime'
  end

  def test_registered_function_ref_renders
    agent = strict_agent
    agent.define_tool(name: 'order_status', description: 'look up an order', parameters: {}, handler: nil) do |_a, _r|
      nil
    end
    contexts = agent.define_contexts
    step = contexts.add_context('default').add_step('help')
    step.set_text('help the caller')
    step.set_functions(%w[order_status])

    assert_includes contexts.to_h, 'default'
  end

  def test_reserved_native_tool_ref_allowed
    # next_step / change_context are auto-injected natives; referencing them
    # explicitly must not be treated as dangling.
    agent = strict_agent
    contexts = agent.define_contexts
    step = contexts.add_context('default').add_step('help')
    step.set_text('help the caller')
    step.set_functions(%w[next_step change_context])

    assert_includes contexts.to_h, 'default'
  end

  def test_functions_none_and_empty_render
    # "none" and [] are explicit disable-all — never dangling.
    ['none', []].each do |value|
      agent = strict_agent
      contexts = agent.define_contexts
      step = contexts.add_context('default').add_step('help')
      step.set_text('help the caller')
      step.set_functions(value)

      assert_includes contexts.to_h, 'default', "expected functions=#{value.inspect} to render"
    end
  end
end
