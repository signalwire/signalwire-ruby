# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Behavioral Contract 8 — AI/LLM structured add_pattern_hint / add_language.
#
# Python reference (`ai_config` mixin): `add_pattern_hint` attaches a STRUCTURED
# hint (`{pattern, hint/replacements, ...}`), not a bare string; `add_language`
# carries `engine`, `model`, and `fillers` (list) into the rendered SWML
# `ai.languages` entry. Degraded ports drop the structure / the engine/model/
# fillers.
#
# ruby is already structured — this is the lock-in test: set a pattern hint
# WITH a replacement + a language WITH engine+model+fillers, render the SWML,
# and assert every field survives into the document.
class AIConfigContractTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def ai_block
    swml = @agent.render_swml
    swml['sections']['main'].find { |v| v.key?('ai') }['ai']
  end

  # Structured pattern hint: pattern + hint + replace(ment) + ignore_case all
  # survive as a HASH in ai.hints (a bare-string impl drops the structure).
  def test_pattern_hint_structure_survives_render
    @agent.add_pattern_hint(hint: 'SignalWire', pattern: 'sw.*',
                            replace: 'SignalWire', ignore_case: true)

    hint = ai_block['hints'].find { |h| h.is_a?(Hash) }

    refute_nil hint, 'structured pattern hint must render as a Hash in ai.hints'
    assert_equal 'sw.*', hint['pattern']
    assert_equal 'SignalWire', hint['hint']
    assert_equal 'SignalWire', hint['replace'], 'the replacement must survive'
    assert_equal true, hint['ignore_case']
  end

  # Language carries engine + model + fillers (both speech + function lists)
  # into the rendered ai.languages entry (a degraded impl drops these keys).
  def test_language_engine_model_fillers_survive_render
    @agent.add_language('English', 'en-US', 'josh',
                        engine: 'elevenlabs', model: 'eleven_turbo_v2_5',
                        speech_fillers: %w[um uh], function_fillers: ['one moment'])

    lang = ai_block['languages'].find { |l| l['code'] == 'en-US' }

    refute_nil lang, 'the added language must render in ai.languages'
    expected = { 'name' => 'English', 'voice' => 'josh', 'engine' => 'elevenlabs',
                 'model' => 'eleven_turbo_v2_5', 'speech_fillers' => %w[um uh],
                 'function_fillers' => ['one moment'] }

    assert_equal expected, lang.slice(*expected.keys),
                 'engine, model, and both filler lists must survive into SWML'
  end

  # The single-filler form collapses to a `fillers` list (Python's combined
  # filler shape) — still a structured list, not dropped.
  def test_single_filler_list_survives_render
    @agent.add_language('French', 'fr-FR', 'amelie',
                        engine: 'elevenlabs', model: 'eleven_turbo_v2_5',
                        speech_fillers: %w[euh alors])

    lang = ai_block['languages'].find { |l| l['code'] == 'fr-FR' }

    refute_nil lang
    assert_equal 'elevenlabs', lang['engine']
    assert_equal 'eleven_turbo_v2_5', lang['model']
    assert_equal %w[euh alors], lang['fillers'], 'a single filler set renders as a fillers list'
  end
end
