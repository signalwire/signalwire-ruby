# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Shared fixtures for the SwmlRenderer test classes.
module SwmlRendererFixtures
  def new_service(name = 'renderer-test')
    SignalWire::SWML::Service.new(name: name)
  end

  def render_and_parse(**)
    JSON.parse(SignalWire::SWML::SwmlRenderer.render_swml(**))
  end
end

# Tests for SwmlRenderer.render_swml — render a full SWML doc and assert its
# exact structure and wire keys.
class SwmlRendererTest < Minitest::Test
  include SwmlRendererFixtures

  def test_render_swml_basic_text_prompt
    doc = render_and_parse(prompt: 'you are helpful', service: new_service)
    main = doc['sections']['main']

    assert_equal 1, main.length
    assert_equal({ 'text' => 'you are helpful' }, main.first['ai']['prompt'])
  end

  def test_render_swml_add_answer_precedes_ai
    doc = render_and_parse(prompt: 'hi', service: new_service, add_answer: true)
    main = doc['sections']['main']

    assert_equal 'answer', main[0].keys.first
    assert_equal 'ai', main[1].keys.first
  end

  def test_render_swml_record_call_wire_keys
    doc = render_and_parse(
      prompt: 'hi', service: new_service,
      record_call: true, record_format: 'wav', record_stereo: false
    )
    rc = doc['sections']['main'].find { |v| v.key?('record_call') }

    # Exact wire keys: format + stereo.
    assert_equal({ 'format' => 'wav', 'stereo' => false }, rc['record_call'])
  end

  def test_render_swml_default_webhook_url_becomes_swaig_defaults
    doc = render_and_parse(
      prompt: 'hi', service: new_service,
      default_webhook_url: 'https://ex.com/swaig'
    )
    ai = doc['sections']['main'].first['ai']

    assert_equal({ 'web_hook_url' => 'https://ex.com/swaig' }, ai['SWAIG']['defaults'])
  end

  def hooks_functions
    doc = render_and_parse(
      prompt: 'hi', service: new_service,
      startup_hook_url: 'https://ex.com/start', hangup_hook_url: 'https://ex.com/end',
      swaig_functions: [
        { 'function' => 'get_weather', 'description' => 'w', 'parameters' => {} },
        # A caller-supplied startup_hook must be skipped (deduped).
        { 'function' => 'startup_hook', 'description' => 'dup' }
      ]
    )
    doc['sections']['main'].first['ai']['SWAIG']['functions']
  end

  def test_render_swml_dedupes_and_orders_hooks
    names = hooks_functions.map { |f| f['function'] }

    assert_equal %w[startup_hook hangup_hook get_weather], names
  end

  def test_render_swml_hook_wire_shape
    startup = hooks_functions.first

    assert_equal 'https://ex.com/start', startup['web_hook_url']
    assert_equal({ 'type' => 'object', 'properties' => {} }, startup['parameters'])
  end

  def test_render_swml_pom_prompt
    pom = [{ 'title' => 'Role', 'body' => 'assistant' }]
    doc = render_and_parse(prompt: pom, service: new_service, prompt_is_pom: true)

    assert_equal({ 'pom' => pom }, doc['sections']['main'].first['ai']['prompt'])
  end

  def test_render_swml_params_merged_into_ai
    doc = render_and_parse(
      prompt: 'hi', service: new_service, params: { 'temperature' => 0.3 }
    )

    assert_in_delta 0.3, doc['sections']['main'].first['ai']['temperature']
  end

  def test_render_swml_yaml_format
    out = SignalWire::SWML::SwmlRenderer.render_swml(
      prompt: 'hi', service: new_service, format: 'yaml'
    )
    parsed = YAML.safe_load(out)

    assert_equal 'ai', parsed['sections']['main'].first.keys.first
  end
end

# Tests for SwmlRenderer.render_function_response_swml — the function-response
# document (a +play+ of the response text plus any provided actions).
class SwmlRendererFunctionResponseTest < Minitest::Test
  include SwmlRendererFixtures

  # The SWML +play+ verb has NO +text+ key — its config is PlayWithURL/
  # PlayWithURLS and spoken text goes through the +say:+ URL scheme. Emitting
  # {"text" => ...} produced a document the SWML schema rejects.
  def test_function_response_plays_text_via_say_url
    out = SignalWire::SWML::SwmlRenderer.render_function_response_swml(
      response_text: 'All done', service: new_service
    )
    main = JSON.parse(out)['sections']['main']

    assert_equal({ 'play' => { 'url' => 'say:All done' } }, main.first)
  end

  # The emitted play config must survive the schema validator — i.e. the
  # renderer routes through the validating Service#add_verb, not the raw
  # document entry point that bypasses it.
  def test_function_response_play_config_passes_schema_validation
    service = new_service
    SignalWire::SWML::SwmlRenderer.render_function_response_swml(
      response_text: 'All done', service: service
    )

    probe = new_service
    probe.reset_document

    assert probe.add_verb('play', service.document.to_h['sections']['main'].first['play'])
  end

  def test_function_response_appends_actions
    out = SignalWire::SWML::SwmlRenderer.render_function_response_swml(
      response_text: 'bye', service: new_service,
      actions: [{ 'hangup' => { 'reason' => 'busy' } }, { 'transfer' => { 'dest' => 'sip:x@y' } }]
    )
    main = JSON.parse(out)['sections']['main']

    assert_equal({ 'play' => { 'url' => 'say:bye' } }, main[0])
    assert_equal({ 'hangup' => { 'reason' => 'busy' } }, main[1])
    assert_equal({ 'transfer' => { 'dest' => 'sip:x@y' } }, main[2])
  end

  # Actions route through the validating Service#add_verb too (matching the
  # reference), so a schema-invalid action config raises instead of silently
  # landing in the document.
  def test_function_response_rejects_schema_invalid_action
    assert_raises(SignalWire::Utils::SchemaValidationError) do
      SignalWire::SWML::SwmlRenderer.render_function_response_swml(
        response_text: 'bye', service: new_service,
        actions: [{ 'hangup' => { 'reason' => 'not-a-valid-reason' } }]
      )
    end
  end

  def test_function_response_empty_text_skips_play
    out = SignalWire::SWML::SwmlRenderer.render_function_response_swml(
      response_text: '', service: new_service,
      actions: [{ 'ai' => { 'prompt' => { 'text' => 'x' } } }]
    )
    main = JSON.parse(out)['sections']['main']

    assert_equal 1, main.length
    assert_equal 'ai', main.first.keys.first
  end
end
