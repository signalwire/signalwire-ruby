# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# Tests for the fluent SWMLBuilder — verb helpers emit exact wire keys, fluent
# chaining returns self, and method_missing auto-vivifies schema verbs.
class SwmlBuilderTest < Minitest::Test
  def setup
    @service = SignalWire::SWML::Service.new(name: 'builder-test')
    @builder = SignalWire::SWML::SWMLBuilder.new(@service)
  end

  def main
    @builder.build['sections']['main']
  end

  def test_answer_empty_config
    assert_same @builder, @builder.answer

    assert_equal({ 'answer' => {} }, main.first)
  end

  def test_answer_with_options
    @builder.answer(max_duration: 30, codecs: 'PCMU')

    assert_equal({ 'answer' => { 'max_duration' => 30, 'codecs' => 'PCMU' } }, main.first)
  end

  def test_hangup_reason
    @builder.hangup(reason: 'busy')

    assert_equal({ 'hangup' => { 'reason' => 'busy' } }, main.first)
  end

  def test_ai_text_prompt_wire_shape
    @builder.ai(prompt_text: 'you are helpful')

    # prompt must be an OBJECT {"text": ...}, never a bare string.
    assert_equal({ 'ai' => { 'prompt' => { 'text' => 'you are helpful' } } }, main.first)
  end

  def test_ai_pom_post_prompt_swaig_and_kwargs
    pom = [{ 'title' => 'Role' }]
    # kwargs merge at the ai verb's TOP level, so they must be keys the closed
    # ai schema declares -- LLM knobs like `temperature` go under `params`.
    @builder.ai(prompt_pom: pom, post_prompt: 'summarize', post_prompt_url: 'https://ex.com/pp',
                swaig: { 'functions' => [] }, params: { 'temperature' => 0.4 })
    cfg = main.first['ai']

    assert_equal({ 'pom' => pom }, cfg['prompt'])
    assert_equal({ 'text' => 'summarize' }, cfg['post_prompt'])
    assert_equal 'https://ex.com/pp', cfg['post_prompt_url']
    assert_equal({ 'functions' => [] }, cfg['SWAIG'])
    assert_in_delta 0.4, cfg['params']['temperature']
  end

  def test_play_url
    @builder.play(url: 'https://ex.com/a.mp3', volume: 5.0)

    assert_equal({ 'play' => { 'url' => 'https://ex.com/a.mp3', 'volume' => 5.0 } }, main.first)
  end

  def test_play_urls_list
    # `urls` entries must be real play URLs (http(s):, say:, ring:, silence:) --
    # a bare filename is rejected by the SWML schema.
    urls = %w[https://ex.com/a.mp3 say:and+now+this]
    @builder.play(urls: urls)

    assert_equal({ 'play' => { 'urls' => urls } }, main.first)
  end

  def test_play_requires_url_or_urls
    assert_raises(ArgumentError) { @builder.play }
  end

  def test_say_prefixes_url
    @builder.say('hello there', voice: 'en-US-Neural', language: 'en-US')
    cfg = main.first['play']

    assert_equal 'say:hello there', cfg['url']
    assert_equal 'en-US-Neural', cfg['say_voice']
    assert_equal 'en-US', cfg['say_language']
  end

  def test_add_section
    @builder.add_section('intro')

    assert @builder.build['sections'].key?('intro')
  end

  def test_reset_clears_document
    @builder.answer.hangup

    refute_empty main
    assert_same @builder, @builder.reset
    assert_empty @builder.build['sections']['main']
  end

  def test_render_is_json_string
    @builder.answer
    parsed = JSON.parse(@builder.render)

    assert_equal 'answer', parsed['sections']['main'].first.keys.first
  end

  def test_fluent_chaining_returns_self
    # `reason` is the engine's closed six-value set (relay_apis.c:1105);
    # 'noAnswer' is one of them and was absent from the schema's old
    # hangup|busy|decline union.
    result = @builder.reset.answer.say('hi').hangup(reason: 'noAnswer')

    assert_same @builder, result
    assert_equal(%w[answer play hangup], main.map { |v| v.keys.first })
  end

  # ---- method_missing (Ruby analog of Python __getattr__) ----

  def test_method_missing_autovivifies_schema_verb
    @builder.denoise

    assert_equal({ 'denoise' => {} }, main.first)
  end

  def test_method_missing_sleep_is_bare_integer
    @builder.sleep(2000)

    # SWML `sleep` emits a raw integer, not a config object.
    assert_equal({ 'sleep' => 2000 }, main.first)
  end

  def test_method_missing_passes_kwargs_as_config
    @builder.record_call(stereo: true, format: 'wav')

    assert_equal({ 'record_call' => { 'stereo' => true, 'format' => 'wav' } }, main.first)
  end

  # N2: a single positional Hash (the SDK's documented string-key style) becomes
  # the config on the vivified path too — not silently dropped.
  def test_method_missing_positional_string_key_hash
    @builder.record_call({ 'stereo' => true, 'format' => 'wav' })

    assert_equal({ 'record_call' => { 'stereo' => true, 'format' => 'wav' } }, main.first)
  end

  def test_method_missing_non_hash_positional_raises
    assert_raises(ArgumentError) { @builder.record_call('wav') }
    assert_raises(ArgumentError) { @builder.record_call({ 'a' => 1 }, { 'b' => 2 }) }
  end

  def test_respond_to_missing_true_for_verbs
    assert_respond_to @builder, :denoise
    assert_respond_to @builder, :sleep
  end

  def test_unknown_method_raises
    assert_raises(NoMethodError) { @builder.definitely_not_a_verb }
  end
end
