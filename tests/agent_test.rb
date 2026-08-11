# frozen_string_literal: true

require 'minitest/autorun'
require 'rack/test'
require 'json'

# Suppress logging during tests
ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'
require_relative '../lib/signalwire/relay/client'

# Shared SWML-rendering helpers for the agent tests.
module AgentRenderHelpers
  # The 'ai' verb block from a rendered SWML document's main section.
  def ai_section(swml)
    swml['sections']['main'].find { |v| v.key?('ai') }['ai']
  end

  # render_swml then return its ai section.
  def rendered_ai(agent)
    ai_section(agent.render_swml)
  end
end

class AgentBaseConstructionTest < Minitest::Test
  include AgentRenderHelpers

  def test_default_construction
    agent = SignalWire::AgentBase.new

    assert_equal 'agent', agent.name
    assert_equal '/', agent.route
    assert_equal '0.0.0.0', agent.host
    assert_equal 3000, agent.port
    assert_instance_of SignalWire::Logging::Logger, agent.logger
  end

  def test_custom_options
    agent = SignalWire::AgentBase.new(
      name: 'my_agent',
      route: '/bot',
      host: '127.0.0.1',
      port: 8080
    )

    assert_equal 'my_agent', agent.name
    assert_equal '/bot', agent.route
    assert_equal '127.0.0.1', agent.host
    assert_equal 8080, agent.port
  end

  def test_route_normalisation
    agent = SignalWire::AgentBase.new(route: '/foo/')

    assert_equal '/foo', agent.route
  end

  def test_empty_route_becomes_root
    agent = SignalWire::AgentBase.new(route: '')

    assert_equal '/', agent.route
  end

  def test_port_from_env
    ENV['PORT'] = '9999'
    agent = SignalWire::AgentBase.new

    assert_equal 9999, agent.port
  ensure
    ENV.delete('PORT')
  end

  def test_basic_auth_auto_generated
    agent = SignalWire::AgentBase.new
    creds = agent.get_basic_auth_credentials

    assert_equal 2, creds.length
    refute_empty creds[0]
    refute_empty creds[1]
  end

  def test_basic_auth_explicit
    agent = SignalWire::AgentBase.new(basic_auth: %w[user pass])

    assert_equal %w[user pass], agent.get_basic_auth_credentials
  end

  def test_basic_auth_from_env
    ENV['SWML_BASIC_AUTH_USER']     = 'envuser'
    ENV['SWML_BASIC_AUTH_PASSWORD'] = 'envpass'
    agent = SignalWire::AgentBase.new

    assert_equal %w[envuser envpass], agent.get_basic_auth_credentials
  ensure
    ENV.delete('SWML_BASIC_AUTH_USER')
    ENV.delete('SWML_BASIC_AUTH_PASSWORD')
  end

  # --- Python parity: extended constructor arguments ---------------

  def test_use_pom_default_true
    agent = SignalWire::AgentBase.new

    assert_equal true, agent.use_pom
  end

  def test_use_pom_explicit_false
    agent = SignalWire::AgentBase.new(use_pom: false)

    assert_equal false, agent.use_pom
  end

  def test_agent_id_auto_generated
    agent = SignalWire::AgentBase.new

    assert_kind_of String, agent.agent_id
    refute_empty agent.agent_id
  end

  def test_agent_id_explicit
    agent = SignalWire::AgentBase.new(agent_id: 'my-test-agent-id')

    assert_equal 'my-test-agent-id', agent.agent_id
  end

  def test_default_webhook_url
    agent = SignalWire::AgentBase.new(default_webhook_url: 'https://hooks.example/swaig')

    assert_equal 'https://hooks.example/swaig', agent.default_webhook_url
  end

  def test_native_functions_default_empty
    agent = SignalWire::AgentBase.new

    assert_equal [], agent.native_functions
  end

  def test_native_functions_explicit
    agent = SignalWire::AgentBase.new(native_functions: %w[get_time check_weather])

    assert_equal %w[get_time check_weather], agent.native_functions
  end

  def test_skill_manager_present
    agent = SignalWire::AgentBase.new

    refute_nil agent.skill_manager
    assert_kind_of SignalWire::Skills::SkillManager, agent.skill_manager
    assert_same agent, agent.skill_manager.agent
  end
end

# get_basic_auth_credentials accessor coverage (split from
# AgentBaseConstructionTest to keep each class under the size limit).
class AgentBasicAuthCredentialsTest < Minitest::Test
  def test_get_basic_auth_credentials_with_source_param
    agent = SignalWire::AgentBase.new(basic_auth: %w[u p])
    creds = agent.get_basic_auth_credentials(include_source: true)

    assert_equal 3, creds.length
    assert_equal 'u', creds[0]
    assert_equal 'p', creds[1]
    assert_kind_of String, creds[2]
  end

  def test_get_basic_auth_credentials_default_two_tuple
    agent = SignalWire::AgentBase.new(basic_auth: %w[u p])
    creds = agent.get_basic_auth_credentials

    assert_equal 2, creds.length
  end

  def test_get_basic_auth_credentials_source_environment
    ENV['SWML_BASIC_AUTH_USER']     = 'eu'
    ENV['SWML_BASIC_AUTH_PASSWORD'] = 'ep'
    agent = SignalWire::AgentBase.new
    _, _, source = agent.get_basic_auth_credentials(include_source: true)

    assert_equal 'environment', source
  ensure
    ENV.delete('SWML_BASIC_AUTH_USER')
    ENV.delete('SWML_BASIC_AUTH_PASSWORD')
  end
end

# on_summary hook registration (split from AgentBaseConstructionTest to keep
# each class under the size limit).
class AgentConstructionSummaryTest < Minitest::Test
  include AgentRenderHelpers

  # --- on_summary as both a hook AND a registration ---------------

  def test_on_summary_block_registration_and_invocation
    agent = SignalWire::AgentBase.new
    received = []
    agent.on_summary(nil) { |sum, raw| received << [sum, raw] }

    summary = { 'topic' => 'billing' }
    raw     = { 'call_id' => 'abc' }
    agent.on_summary(summary, raw)

    assert_equal 1, received.length
    assert_equal summary, received.first[0]
    assert_equal raw,     received.first[1]
  end

  def test_on_summary_no_callback_no_op
    agent = SignalWire::AgentBase.new
    # Calling without a registered callback should not raise.
    assert_nil agent.on_summary({ 'topic' => 'x' }, nil)
  end
end

# define_tool params, hints, languages, and relay-client construction (split
# from AgentBaseConstructionTest to keep each class under the size limit).
class AgentConstructionToolsAndLanguagesTest < Minitest::Test
  include AgentRenderHelpers

  # --- define_tool: extended Python parity params ------------------

  def test_define_tool_with_wait_file_and_loops
    agent = SignalWire::AgentBase.new
    agent.define_tool(name: 'play_tune', description: 'play a tune', parameters: {},
                      wait_file: 'https://example.com/wait.mp3', wait_file_loops: 3, handler: nil) do |_args, _raw|
      { 'response' => 'ok' }
    end
    tool = agent.define_tools.find { |d| d['function'] == 'play_tune' }

    refute_nil tool
    assert_equal 'https://example.com/wait.mp3', tool['wait_file']
    assert_equal 3, tool['wait_file_loops']
  end

  def test_define_tool_with_webhook_url
    agent = SignalWire::AgentBase.new
    agent.define_tool(
      name: 'lookup',
      description: 'lookup',
      parameters: {},
      webhook_url: 'https://example.com/swaig', handler: nil
    ) { |_args, _raw| {} }
    defs = agent.define_tools
    tool = defs.find { |d| d['function'] == 'lookup' }

    assert_equal 'https://example.com/swaig', tool['webhook_url']
  end

  def test_define_tool_with_required_array
    agent = SignalWire::AgentBase.new
    agent.define_tool(
      name: 'verify',
      description: 'verify',
      parameters: { 'type' => 'object', 'properties' => { 'a' => { 'type' => 'string' } } },
      required: ['a'], handler: nil
    ) { |_args, _raw| {} }
    defs = agent.define_tools
    tool = defs.find { |d| d['function'] == 'verify' }

    assert_includes tool['parameters']['required'], 'a'
  end

  def test_define_tool_is_typed_handler_marker
    agent = SignalWire::AgentBase.new
    agent.define_tool(
      name: 't',
      description: 'd',
      parameters: {},
      is_typed_handler: true, handler: nil
    ) { |_args, _raw| {} }
    defs = agent.define_tools
    tool = defs.find { |d| d['function'] == 't' }

    assert_equal true, tool['is_typed_handler']
  end

  # --- Python parity: add_pattern_hint(hint, pattern, replace, ...) -

  def test_add_pattern_hint_python_positional
    agent = SignalWire::AgentBase.new
    agent.add_pattern_hint('hello', '\\bhi\\b', 'hello there', ignore_case: true)
    hints = rendered_ai(agent)['hints']

    refute_nil hints
    entry = hints.find { |h| h.is_a?(Hash) && h['hint'] == 'hello' }

    refute_nil entry
    assert_equal '\\bhi\\b', entry['pattern']
    assert_equal 'hello there', entry['replace']
    assert_equal true, entry['ignore_case']
  end

  # The legacy single-positional form (`add_pattern_hint('foo')`) was removed:
  # it had no reference counterpart and emitted a different wire shape. All
  # three of hint/pattern/replace are now required, matching the reference.
  def test_add_pattern_hint_requires_hint_pattern_and_replace
    agent = SignalWire::AgentBase.new

    assert_raises(ArgumentError) { agent.add_pattern_hint('foo') }
    assert_raises(ArgumentError) { agent.add_pattern_hint('foo', 'bar') }
  end

  # ignore_case defaults to false — asserted WITHOUT passing it, so the default
  # itself is under test (passing it explicitly would prove nothing).
  def test_add_pattern_hint_ignore_case_defaults_to_false
    agent = SignalWire::AgentBase.new
    agent.add_pattern_hint('hello', '\\bhi\\b', 'hello there')
    hint = agent.instance_variable_get(:@hints).first

    assert_equal false, hint['ignore_case']
  end
end

# add_language + relay-client construction (split from
# AgentConstructionToolsAndLanguagesTest to keep each class under the limit).
class AgentConstructionLanguagesAndRelayTest < Minitest::Test
  include AgentRenderHelpers

  # --- Python parity: add_language(name, code, voice, ...) ---------

  def test_add_language_python_positional_basic
    agent = SignalWire::AgentBase.new
    agent.add_language('English', 'en-US', 'en-US-Neural2-F')
    langs = agent.instance_variable_get(:@languages)

    assert_equal 1, langs.length
    assert_equal 'English', langs.first['name']
    assert_equal 'en-US', langs.first['code']
    assert_equal 'en-US-Neural2-F', langs.first['voice']
  end

  def test_add_language_with_engine_and_model
    agent = SignalWire::AgentBase.new
    agent.add_language('English', 'en-US', 'josh', engine: 'elevenlabs', model: 'eleven_turbo_v2_5')
    lang = agent.instance_variable_get(:@languages).first

    assert_equal 'josh', lang['voice']
    assert_equal 'elevenlabs', lang['engine']
    assert_equal 'eleven_turbo_v2_5', lang['model']
  end

  def test_add_language_combined_voice_string_parsed
    agent = SignalWire::AgentBase.new
    agent.add_language('English', 'en-US', 'elevenlabs.josh:eleven_turbo_v2_5')
    lang = agent.instance_variable_get(:@languages).first

    assert_equal 'josh', lang['voice']
    assert_equal 'elevenlabs', lang['engine']
    assert_equal 'eleven_turbo_v2_5', lang['model']
  end

  def test_add_language_speech_and_function_fillers
    agent = SignalWire::AgentBase.new
    agent.add_language('English', 'en-US', 'voice', speech_fillers: %w[um uh],
                                                    function_fillers: ['one moment'], engine: 'eng', model: 'm')
    lang = agent.instance_variable_get(:@languages).first

    assert_equal %w[um uh], lang['speech_fillers']
    assert_equal ['one moment'], lang['function_fillers']
  end

  # The preformed-hash form (`add_language(config_hash)`) was removed: the
  # reference spells that capability #set_languages. name/code/voice are now all
  # required, matching the reference's `add_language(name, code, voice, ...)`.
  def test_add_language_requires_name_code_and_voice
    agent = SignalWire::AgentBase.new

    assert_raises(ArgumentError) { agent.add_language('Spanish') }
    assert_raises(ArgumentError) { agent.add_language('Spanish', 'es-ES') }
  end

  def test_set_languages_is_the_hash_config_path
    agent = SignalWire::AgentBase.new
    agent.set_languages([{ 'name' => 'Spanish', 'code' => 'es-ES', 'voice' => 'voice' }])
    lang = agent.instance_variable_get(:@languages).first

    assert_equal 'Spanish', lang['name']
  end

  # --- Python parity: relay client host + max_active_calls ---------

  def test_relay_client_accepts_host_keyword
    client = SignalWire::Relay::Client.new(
      project: 'p', token: 't', host: 'myspace'
    )
    # @host gets resolved to fully qualified hostname.
    assert_equal 'myspace.signalwire.com', client.host
  end

  def test_relay_client_max_active_calls_default_nil
    client = SignalWire::Relay::Client.new(project: 'p', token: 't', host: 'm')

    assert_nil client.max_active_calls
  end

  def test_relay_client_max_active_calls_explicit
    client = SignalWire::Relay::Client.new(
      project: 'p', token: 't', host: 'm', max_active_calls: 7
    )

    assert_equal 7, client.max_active_calls
  end

  def test_relay_client_max_active_calls_floors_at_one
    client = SignalWire::Relay::Client.new(
      project: 'p', token: 't', host: 'm', max_active_calls: 0
    )

    assert_equal 1, client.max_active_calls
  end

  def test_relay_client_max_active_calls_from_env
    ENV['RELAY_MAX_ACTIVE_CALLS'] = '42'
    client = SignalWire::Relay::Client.new(project: 'p', token: 't', host: 'm')

    assert_equal 42, client.max_active_calls
  ensure
    ENV.delete('RELAY_MAX_ACTIVE_CALLS')
  end

  def test_relay_client_legacy_space_kwarg_still_works
    client = SignalWire::Relay::Client.new(
      project: 'p', token: 't', space: 'oldway'
    )

    assert_equal 'oldway.signalwire.com', client.host
  end
end

# =========================================================================
# Prompt tests
# =========================================================================
class AgentPromptTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_text_mode
    @agent.set_prompt_text('Hello world')

    assert_equal 'Hello world', @agent.get_prompt
  end

  def test_pom_mode_direct
    pom = [{ 'title' => 'Intro', 'body' => 'Hi' }]
    @agent.set_prompt_pom(pom)

    assert_equal pom, @agent.get_prompt
  end

  def test_pom_sections
    @agent.prompt_add_section('Personality', 'Be helpful')
    @agent.prompt_add_section('Rules', nil, bullets: ['Be concise', 'Be accurate'])
    prompt = @agent.get_prompt

    assert_equal 2, prompt.length
    personality, rules = prompt

    assert_equal 'Personality', personality['title']
    assert_equal 'Be helpful', personality['body']
    assert_equal 'Rules', rules['title']
    assert_equal ['Be concise', 'Be accurate'], rules['bullets']
  end

  def test_prompt_add_to_section
    @agent.prompt_add_section('Intro', 'Hello')
    @agent.prompt_add_to_section('Intro', ' World')
    prompt = @agent.get_prompt

    assert_equal 'Hello World', prompt[0]['body']
  end

  def test_prompt_add_subsection
    @agent.prompt_add_section('Main', 'Top-level body')
    @agent.prompt_add_subsection('Main', 'Sub', 'Sub body', bullets: %w[a b])
    subsections = @agent.get_prompt[0]['subsections']

    assert_equal 1, subsections.length
    sub = subsections[0]

    assert_equal 'Sub', sub['title']
    assert_equal 'Sub body', sub['body']
    assert_equal %w[a b], sub['bullets']
  end

  def test_prompt_has_section
    @agent.prompt_add_section('Foo', 'bar')

    assert @agent.prompt_has_section?('Foo')
    refute @agent.prompt_has_section?('Baz')
  end

  def test_text_mode_clears_pom
    @agent.prompt_add_section('Sec', 'body')
    @agent.set_prompt_text('Raw text')

    assert_equal 'Raw text', @agent.get_prompt
  end

  def test_pom_mode_clears_text
    @agent.set_prompt_text('Raw text')
    @agent.prompt_add_section('Sec', 'body')
    prompt = @agent.get_prompt

    assert_instance_of Array, prompt
    assert_equal 'Sec', prompt[0]['title']
  end

  def test_post_prompt
    @agent.set_post_prompt('Summarize the call')
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 'Summarize the call', ai['post_prompt']['text']
  end
end

# =========================================================================
# Tool tests
# =========================================================================
class AgentToolTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_define_tool_with_block
    @agent.define_tool(name: 'greet', description: 'Say hello',
                       parameters: { 'name' => { 'type' => 'string', 'description' => 'Name' } },
                       handler: nil) do |args, _raw|
      SignalWire::Swaig::FunctionResult.new("Hello, #{args['name']}!")
    end
    tools = @agent.define_tools

    assert_equal 1, tools.length
    assert_equal 'greet', tools[0]['function']
    assert_equal 'Say hello', tools[0]['description']
  end

  def test_register_swaig_function
    dm_func = { 'function' => 'weather', 'description' => 'Get weather',
                'parameters' => { 'type' => 'object', 'properties' => {} }, 'data_map' => { 'webhooks' => [] } }
    @agent.register_swaig_function(dm_func)
    tools = @agent.define_tools

    assert_equal 1, tools.length
    assert_equal 'weather', tools[0]['function']
    assert tools[0].key?('data_map')
  end

  def test_on_function_call_dispatch
    @agent.define_tool(
      name: 'echo',
      description: 'Echo back',
      parameters: {}, handler: nil
    ) do |args, _raw|
      SignalWire::Swaig::FunctionResult.new("Echo: #{args['text']}")
    end

    result = @agent.on_function_call('echo', { 'text' => 'hello' }, {})

    assert_equal 'Echo: hello', result['response']
  end

  def test_on_function_call_unknown
    result = @agent.on_function_call('nonexistent', {}, {})

    assert_includes result['response'], 'not found'
  end

  def test_tool_with_fillers
    @agent.define_tool(
      name: 'slow_op',
      description: 'Slow operation',
      fillers: { 'en-US' => ['Please wait...', 'Working on it...'] }, parameters: {}, handler: nil
    ) { |_, _| SignalWire::Swaig::FunctionResult.new('Done') }

    tools = @agent.define_tools

    assert_equal({ 'en-US' => ['Please wait...', 'Working on it...'] }, tools[0]['fillers'])
  end

  def test_define_tool_returns_self
    result = @agent.define_tool(name: 'x', description: 'x', parameters: {}, handler: nil) { |_, _| }

    assert_same @agent, result
  end
end

# =========================================================================
# AI Config tests
# =========================================================================
class AgentAIConfigTest < Minitest::Test
  include AgentRenderHelpers

  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_add_hint
    @agent.add_hint('SignalWire')
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_includes ai['hints'], 'SignalWire'
  end

  def test_add_hints
    @agent.add_hints(%w[one two three])
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal %w[one two three], ai['hints']
  end

  def test_add_language
    @agent.add_language('English', 'en-US', 'rachel')
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 1, ai['languages'].length
    assert_equal 'English', ai['languages'][0]['name']
  end

  def test_set_languages
    langs = [
      { 'name' => 'English', 'code' => 'en-US', 'voice' => 'rachel' },
      { 'name' => 'French', 'code' => 'fr-FR', 'voice' => 'amelie' }
    ]
    @agent.set_languages(langs)
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 2, ai['languages'].length
  end

  def test_set_param
    @agent.set_param('temperature', 0.7)
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_in_delta(0.7, ai['params']['temperature'])
  end

  def test_set_params
    @agent.set_params({ 'temperature' => 0.7, 'top_p' => 0.9 })
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_in_delta(0.7, ai['params']['temperature'])
    assert_in_delta(0.9, ai['params']['top_p'])
  end

  def test_set_global_data
    @agent.set_global_data({ 'key' => 'value' })
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 'value', ai['global_data']['key']
  end

  def test_update_global_data
    @agent.set_global_data({ 'a' => 1 })
    @agent.update_global_data({ 'b' => 2 })
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 1, ai['global_data']['a']
    assert_equal 2, ai['global_data']['b']
  end

  def test_set_native_functions
    @agent.set_native_functions(['check_for_input'])
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_includes ai['SWAIG']['native_functions'], 'check_for_input'
  end
end

# Pronunciations, internal fillers, function includes, and LLM params (split
# from AgentAIConfigTest to keep each class under the size limit).
class AgentAIConfigFillersAndIncludesTest < Minitest::Test
  include AgentRenderHelpers

  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_add_pronunciation
    @agent.add_pronunciation('SW', 'SignalWire')
    ai = rendered_ai(@agent)

    assert_equal 'SW', ai['pronounce'][0]['replace']
    assert_equal 'SignalWire', ai['pronounce'][0]['with']
  end

  def test_set_pronunciations
    rules = [{ 'replace' => 'AI', 'with' => 'Artificial Intelligence' }]
    @agent.set_pronunciations(rules)

    assert_equal 1, rendered_ai(@agent)['pronounce'].length
  end

  def test_set_internal_fillers
    @agent.set_internal_fillers({ 'next_step' => { 'en-US' => ['Moving on...'] } })
    ai = rendered_ai(@agent)

    assert_equal ['Moving on...'], ai['SWAIG']['internal_fillers']['next_step']['en-US']
  end

  def test_add_internal_filler
    @agent.add_internal_filler('check_time', 'en-US', ['Checking time...'])
    ai = rendered_ai(@agent)

    assert_equal ['Checking time...'], ai['SWAIG']['internal_fillers']['check_time']['en-US']
  end

  def test_enable_debug_events
    @agent.enable_debug_events(2)
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert ai['params'].key?('debug_webhook_url')
    assert_equal 2, ai['params']['debug_webhook_level']
  end

  def test_add_function_include
    @agent.add_function_include('https://example.com/funcs', %w[fn1 fn2],
                                meta_data: { 'key' => 'val' })
    inc = rendered_ai(@agent)['SWAIG']['includes']

    assert_equal 1, inc.length
    assert_equal 'https://example.com/funcs', inc[0]['url']
    assert_equal %w[fn1 fn2], inc[0]['functions']
    assert_equal({ 'key' => 'val' }, inc[0]['meta_data'])
  end

  def test_set_function_includes
    includes = [{ 'url' => 'https://a.com', 'functions' => ['f1'] }]
    @agent.set_function_includes(includes)

    assert_equal 1, rendered_ai(@agent)['SWAIG']['includes'].length
  end

  def test_set_prompt_llm_params
    @agent.set_prompt_text('Hello')
    @agent.set_prompt_llm_params(temperature: 0.3, top_p: 0.9)
    prompt = rendered_ai(@agent)['prompt']

    assert_in_delta(0.3, prompt['temperature'])
    assert_in_delta(0.9, prompt['top_p'])
    assert_equal 'Hello', prompt['text']
  end

  def test_set_post_prompt_llm_params
    @agent.set_post_prompt('Summarize')
    @agent.set_post_prompt_llm_params(model: 'gpt-4o-mini', temperature: 0.5)
    post = rendered_ai(@agent)['post_prompt']

    assert_in_delta(0.5, post['temperature'])
    assert_equal 'gpt-4o-mini', post['model']
    assert_equal 'Summarize', post['text']
  end

  def test_add_pattern_hint
    @agent.add_pattern_hint('SignalWire', 'SW.*', 'SignalWire')
    swml = @agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    pattern_hint = ai['hints'].find { |h| h.is_a?(Hash) }

    assert_equal 'SW.*', pattern_hint['pattern']
    assert_equal 'SignalWire', pattern_hint['hint']
  end
end

# =========================================================================
# Verb management tests
# =========================================================================
class AgentVerbTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_pre_answer_verbs
    @agent.add_pre_answer_verb('play', { 'url' => 'https://example.com/ring.mp3' })
    swml = @agent.render_swml
    main = swml['sections']['main']
    # Pre-answer verb should come before 'answer'
    first = main[0]

    assert first.key?('play')
    assert_equal 'https://example.com/ring.mp3', first['play']['url']
  end

  def test_clear_pre_answer_verbs
    @agent.add_pre_answer_verb('play', { 'url' => 'https://example.com/ring.mp3' })
    @agent.clear_pre_answer_verbs
    swml = @agent.render_swml
    main = swml['sections']['main']

    assert_equal 'answer', main[0].keys.first
  end

  def test_post_answer_verbs
    @agent.add_post_answer_verb('play', { 'url' => 'https://example.com/welcome.mp3' })
    swml = @agent.render_swml
    main = swml['sections']['main']
    # After answer, before AI
    answer_idx = main.index { |v| v.key?('answer') }
    ai_idx     = main.index { |v| v.key?('ai') }
    play_idx   = main.index { |v| v.key?('play') }

    assert_operator play_idx, :>, answer_idx
    assert_operator play_idx, :<, ai_idx
  end

  def test_clear_post_answer_verbs
    @agent.add_post_answer_verb('play', {})
    @agent.clear_post_answer_verbs
    swml = @agent.render_swml
    main = swml['sections']['main']

    refute(main.any? { |v| v.key?('play') })
  end

  def test_post_ai_verbs
    @agent.add_post_ai_verb('hangup', {})
    swml = @agent.render_swml
    main = swml['sections']['main']
    ai_idx     = main.index { |v| v.key?('ai') }
    hangup_idx = main.index { |v| v.key?('hangup') }

    assert_operator hangup_idx, :>, ai_idx
  end

  def test_clear_post_ai_verbs
    @agent.add_post_ai_verb('hangup', {})
    @agent.clear_post_ai_verbs
    swml = @agent.render_swml
    main = swml['sections']['main']

    refute(main.any? { |v| v.key?('hangup') })
  end

  def test_answer_verb_config
    @agent.add_answer_verb({ 'max_duration' => 3600 })
    swml = @agent.render_swml
    main = swml['sections']['main']
    answer = main.find { |v| v.key?('answer') }

    assert_equal 3600, answer['answer']['max_duration']
  end
end

# =========================================================================
# Contexts tests
# =========================================================================
class AgentContextsTest < Minitest::Test
  def test_define_contexts_returns_builder
    agent = SignalWire::AgentBase.new
    builder = agent.define_contexts

    assert_instance_of SignalWire::Contexts::ContextBuilder, builder
  end

  def test_contexts_alias
    agent = SignalWire::AgentBase.new

    assert_same agent.define_contexts, agent.contexts
  end

  def test_contexts_rendered_in_swml
    agent = SignalWire::AgentBase.new
    ctx = agent.define_contexts.add_context('default')
    ctx.add_step('greeting').set_text('Say hello')
    main = agent.render_swml['sections']['main']
    # contexts lives inside the prompt object (reference
    # core/swml_handler.py:191) -- the ai schema is closed and would reject a
    # top-level key.
    contexts = main.find { |v| v.key?('ai') }.dig('ai', 'prompt', 'contexts')

    refute_nil contexts, 'Expected contexts in the AI prompt config'
    assert contexts.key?('default')
  end
end

# =========================================================================
# Skill integration tests
# =========================================================================
class AgentSkillTest < Minitest::Test
  def test_add_skill_datetime
    agent = SignalWire::AgentBase.new
    agent.add_skill('datetime')

    assert agent.has_skill?('datetime')
    assert_includes agent.list_skills, 'datetime'
    # Should have registered tools
    tools = agent.define_tools
    tool_names = tools.map { |t| t['function'] }

    assert_includes tool_names, 'get_current_time'
    assert_includes tool_names, 'get_current_date'
  end

  def test_add_skill_returns_self
    agent = SignalWire::AgentBase.new
    result = agent.add_skill('datetime')

    assert_same agent, result
  end

  def test_remove_skill
    agent = SignalWire::AgentBase.new
    agent.add_skill('datetime')
    agent.remove_skill('datetime')

    refute agent.has_skill?('datetime')
  end

  def test_unknown_skill_raises
    agent = SignalWire::AgentBase.new
    assert_raises(ArgumentError) { agent.add_skill('nonexistent_skill_xyz') }
  end
end

# =========================================================================
# render_swml tests
# =========================================================================
class AgentRenderSwmlTest < Minitest::Test
  include AgentRenderHelpers

  def test_basic_structure
    agent = SignalWire::AgentBase.new
    swml = agent.render_swml

    assert_equal '1.0.0', swml['version']
    assert swml.key?('sections')
    assert swml['sections'].key?('main')
  end

  def test_auto_answer
    agent = SignalWire::AgentBase.new(auto_answer: true)
    swml = agent.render_swml
    main = swml['sections']['main']

    assert(main.any? { |v| v.key?('answer') })
  end

  def test_no_auto_answer
    agent = SignalWire::AgentBase.new(auto_answer: false)
    swml = agent.render_swml
    main = swml['sections']['main']

    refute(main.any? { |v| v.key?('answer') })
  end

  def test_record_call
    agent = SignalWire::AgentBase.new(record_call: true, record_format: 'wav', record_stereo: false)
    swml = agent.render_swml
    main = swml['sections']['main']
    rec = main.find { |v| v.key?('record_call') }

    assert rec
    assert_equal 'wav', rec['record_call']['format']
    assert_equal false, rec['record_call']['stereo']
  end

  def test_with_tools
    agent = SignalWire::AgentBase.new
    agent.define_tool(name: 'foo', description: 'Foo tool', parameters: {}, handler: nil) { |_, _| }
    ai = rendered_ai(agent)

    assert ai.key?('SWAIG')
    funcs = ai['SWAIG']['functions']

    assert_equal 1, funcs.length
    assert_equal 'foo', funcs[0]['function']
  end

  def test_with_pom
    agent = SignalWire::AgentBase.new
    agent.prompt_add_section('Intro', 'Hello')
    pom = rendered_ai(agent)['prompt']['pom']

    assert_instance_of Array, pom
    assert_equal 'Intro', pom[0]['title']
  end

  def test_with_text_prompt
    agent = SignalWire::AgentBase.new
    agent.set_prompt_text('You are helpful.')

    assert_equal 'You are helpful.', rendered_ai(agent)['prompt']['text']
  end

  def test_with_params
    agent = SignalWire::AgentBase.new
    agent.set_params({ 'temperature' => 0.5 })

    assert_in_delta(0.5, rendered_ai(agent)['params']['temperature'])
  end

  # Pre-answer → answer → record_call → post-answer → ai → post-ai.
  EXPECTED_PHASE_ORDER = %w[set answer record_call play ai hangup].freeze

  def five_phase_agent
    agent = SignalWire::AgentBase.new(record_call: true)
    agent.add_pre_answer_verb('set', { 'x' => '1' })
    agent.add_post_answer_verb('play', { 'url' => 'https://example.com/welcome.mp3' })
    agent.add_post_ai_verb('hangup', {})
    agent
  end

  def test_5_phase_ordering
    keys = five_phase_agent.render_swml['sections']['main'].map { |v| v.keys.first }

    indices = EXPECTED_PHASE_ORDER.map { |verb| keys.index(verb) }

    refute_includes indices, nil, "missing expected verb in #{keys.inspect}"
    assert_equal indices.sort, indices, "verbs out of phase order: #{keys.inspect}"
  end
end

# webhook/post-prompt URL rendering (split from AgentRenderSwmlTest to keep
# each class under the size limit).
class AgentRenderSwmlUrlsTest < Minitest::Test
  include AgentRenderHelpers

  def test_webhook_url_in_swml
    agent = SignalWire::AgentBase.new(basic_auth: %w[u p])
    agent.define_tool(name: 'test', description: 'Test', parameters: {}, handler: nil) { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    default_url = ai['SWAIG']['defaults']['web_hook_url']

    assert_includes default_url, '/swaig'
    assert_includes default_url, 'u:p@'
  end

  def test_post_prompt_url_in_swml
    agent = SignalWire::AgentBase.new(basic_auth: %w[u p])
    agent.set_post_prompt('Summarize')
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_includes ai['post_prompt_url'], '/post_prompt'
  end

  def test_web_hook_url_override
    agent = SignalWire::AgentBase.new
    agent.set_web_hook_url('https://custom.example.com/hook')
    agent.define_tool(name: 'test', description: 'Test', parameters: {}, handler: nil) { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 'https://custom.example.com/hook', ai['SWAIG']['defaults']['web_hook_url']
  end

  def test_post_prompt_url_override
    agent = SignalWire::AgentBase.new
    agent.set_post_prompt('Sum')
    agent.set_post_prompt_url('https://custom.example.com/pp')
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 'https://custom.example.com/pp', ai['post_prompt_url']
  end
end

# =========================================================================
# Dynamic config tests
# =========================================================================
class AgentDynamicConfigTest < Minitest::Test
  include AgentRenderHelpers

  def test_dynamic_config_callback_applied
    agent = SignalWire::AgentBase.new
    agent.set_prompt_text('Original')
    agent.set_dynamic_config_callback(nil) do |_query, _body, _headers, ephemeral|
      ephemeral.set_prompt_text('Modified')
    end
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']

    assert_equal 'Modified', ai['prompt']['text']
  end

  def test_original_not_mutated
    agent = SignalWire::AgentBase.new
    agent.set_prompt_text('Original')
    agent.set_dynamic_config_callback(nil) do |_query, _body, _headers, ephemeral|
      ephemeral.set_prompt_text('Modified')
      ephemeral.add_hint('NewHint')
    end
    # Render triggers dynamic config
    agent.render_swml

    # Original should be untouched
    assert_equal 'Original', agent.get_prompt
    # Render again to verify original state persists
    assert_equal 'Modified', rendered_ai(agent)['prompt']['text']
  end

  def test_dynamic_config_can_add_tools
    agent = SignalWire::AgentBase.new
    agent.set_dynamic_config_callback(nil) do |_q, _b, _h, ephemeral|
      ephemeral.define_tool(name: 'dynamic_tool', description: 'Added dynamically',
                            parameters: {}, handler: nil) { |_, _| }
    end
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    func_names = (ai.dig('SWAIG', 'functions') || []).map { |f| f['function'] }

    assert_includes func_names, 'dynamic_tool'
    # Original should have no tools
    assert_empty agent.define_tools
  end
end

# =========================================================================
# Rack app / HTTP tests
# =========================================================================
class AgentRackTest < Minitest::Test
  include Rack::Test::Methods
  include AgentRenderHelpers

  def app
    @agent = SignalWire::AgentBase.new(basic_auth: %w[testuser testpass])
    @agent.set_prompt_text('Hello')
    # secure: false — these cases exercise Rack ROUTING, not the `secure` token
    # contract (which has its own suite in swaig_token_enforcement_test.rb). A
    # secure tool would rightly refuse an untokened POST and mask the routing
    # assertion.
    @agent.define_tool(name: 'echo', description: 'Echo', parameters: {},
                       secure: false, handler: nil) do |args, _raw|
      SignalWire::Swaig::FunctionResult.new("Echo: #{args['msg']}")
    end
    @agent.on_summary(nil) do |summary, _raw|
      @last_summary = summary
    end
    @agent.rack_app
  end

  def auth_header
    "Basic #{['testuser:testpass'].pack('m0')}"
  end

  # POST +payload+ as authenticated JSON to +path+.
  def post_json(path, payload)
    header 'Authorization', auth_header
    header 'Content-Type', 'application/json'
    post path, JSON.generate(payload)
  end

  # --- health / ready (no auth) ---

  def test_health_endpoint
    get '/health'

    assert_equal 200, last_response.status
    data = JSON.parse(last_response.body)

    assert_equal 'healthy', data['status']
  end

  def test_ready_endpoint
    get '/ready'

    assert_equal 200, last_response.status
    data = JSON.parse(last_response.body)

    assert_equal 'ready', data['status']
  end

  # --- auth required ---

  def test_swml_endpoint_requires_auth
    get '/'

    assert_equal 401, last_response.status
  end

  def test_swml_endpoint_wrong_auth
    header 'Authorization', "Basic #{['wrong:creds'].pack('m0')}"
    get '/'

    assert_equal 401, last_response.status
  end

  # --- SWML endpoint ---

  def test_swml_endpoint_get
    header 'Authorization', auth_header
    get '/'

    assert_equal 200, last_response.status
    swml = JSON.parse(last_response.body)

    assert_equal '1.0.0', swml['version']
    assert_equal 'Hello', ai_section(swml)['prompt']['text']
  end

  def test_swml_endpoint_post
    post_json('/', { 'call_id' => 'abc-123' })

    assert_equal 200, last_response.status
    swml = JSON.parse(last_response.body)

    assert_equal '1.0.0', swml['version']
  end

  # --- SWAIG dispatch ---

  def test_swaig_dispatch
    payload = { 'function' => 'echo', 'argument' => { 'parsed' => [{ 'msg' => 'test' }] }, 'call_id' => 'call-1' }
    post_json('/swaig', payload)

    assert_equal 200, last_response.status
    result = JSON.parse(last_response.body)

    assert_equal 'Echo: test', result['response']
  end

  def test_swaig_dispatch_no_function
    post_json('/swaig', {})

    assert_equal 400, last_response.status
  end

  def test_swaig_dispatch_unknown_function
    post_json('/swaig', { 'function' => 'unknown', 'argument' => { 'parsed' => [{}] } })

    assert_equal 200, last_response.status
    result = JSON.parse(last_response.body)

    assert_includes result['response'], 'not found'
  end

  # --- post_prompt ---

  def test_post_prompt_endpoint
    # `parsed` is an array per the canonical wire shape; the summary is
    # parsed[0] (matches the Python/TS extraction order: summary -> parsed[0] -> raw).
    post_json('/post_prompt', { 'post_prompt_data' => { 'raw' => 'Summary text',
                                                        'parsed' => [{ 'summary' => 'Short' }] } })

    assert_equal 200, last_response.status
    # Callback should have been called
    assert_equal({ 'summary' => 'Short' }, @last_summary)
  end

  # --- security headers ---

  def test_security_headers
    header 'Authorization', auth_header
    get '/'

    assert_equal 'nosniff', last_response.headers['x-content-type-options']
    assert_equal 'DENY', last_response.headers['x-frame-options']
    assert_includes last_response.headers['cache-control'], 'no-store'
  end
end

# =========================================================================
# Rack app with custom route
# =========================================================================
class AgentCustomRouteRackTest < Minitest::Test
  include Rack::Test::Methods

  def app
    @agent = SignalWire::AgentBase.new(
      route: '/bot',
      basic_auth: %w[u p]
    )
    @agent.set_prompt_text('Custom route')
    @agent.rack_app
  end

  def auth_header
    "Basic #{['u:p'].pack('m0')}"
  end

  def test_custom_route_swml
    header 'Authorization', auth_header
    get '/bot'

    assert_equal 200, last_response.status
    swml = JSON.parse(last_response.body)

    assert_equal '1.0.0', swml['version']
  end

  def test_custom_route_swaig
    header 'Authorization', auth_header
    header 'Content-Type', 'application/json'
    post '/bot/swaig', JSON.generate({ 'function' => 'test' })

    assert_equal 200, last_response.status
  end
end

# =========================================================================
# Method chaining tests
# =========================================================================
class AgentMethodChainingTest < Minitest::Test
  # Every fluent config method, as a callable that invokes it on its argument.
  # Each must return self for chaining (Python/Ruby builder parity).
  CHAINABLE_CONFIG_CALLS = [
    ->(a) { a.set_prompt_text('x') },
    ->(a) { a.set_post_prompt('x') },
    ->(a) { a.set_prompt_pom([]) },
    ->(a) { a.prompt_add_section('T', 'B') },
    ->(a) { a.prompt_add_to_section('T', 'x') },
    ->(a) { a.prompt_add_subsection('T', 'S', 'B') },
    ->(a) { a.add_hint('x') },
    ->(a) { a.add_hints(['x']) },
    ->(a) { a.add_pattern_hint('h', 'p', 'r') },
    ->(a) { a.add_language('E', 'en', 'v') },
    ->(a) { a.set_languages([]) },
    ->(a) { a.add_pronunciation('a', 'b') },
    ->(a) { a.set_pronunciations([]) },
    ->(a) { a.set_param('k', 'v') },
    ->(a) { a.set_params({}) },
    ->(a) { a.set_global_data({}) },
    ->(a) { a.update_global_data({}) },
    ->(a) { a.set_native_functions([]) },
    ->(a) { a.set_internal_fillers({}) },
    ->(a) { a.add_internal_filler('f', 'en', ['x']) },
    :enable_debug_events.to_proc,
    ->(a) { a.add_function_include('url', ['f']) },
    ->(a) { a.set_function_includes([]) },
    ->(a) { a.set_prompt_llm_params(temperature: 0.5) },
    ->(a) { a.set_post_prompt_llm_params(temperature: 0.5) },
    ->(a) { a.add_pre_answer_verb('play', {}) },
    :clear_pre_answer_verbs.to_proc,
    ->(a) { a.add_answer_verb({}) },
    ->(a) { a.add_post_answer_verb('play', {}) },
    :clear_post_answer_verbs.to_proc,
    ->(a) { a.add_post_ai_verb('hangup', {}) },
    :clear_post_ai_verbs.to_proc,
    ->(a) { a.set_dynamic_config_callback(nil) { |*| } },
    ->(a) { a.manual_set_proxy_url('x') },
    ->(a) { a.set_web_hook_url('x') },
    ->(a) { a.set_post_prompt_url('x') },
    ->(a) { a.add_swaig_query_params({}) },
    :clear_swaig_query_params.to_proc,
    :enable_debug_routes.to_proc,
    :enable_sip_routing.to_proc,
    ->(a) { a.register_sip_username('u') },
    ->(a) { a.on_summary(nil) {} },
    ->(a) { a.on_debug_event(nil) {} },
    ->(a) { a.register_swaig_function({ 'function' => 'x' }) },
    ->(a) { a.remove_skill('nonexistent') }
  ].freeze

  def test_all_config_methods_return_self
    agent = SignalWire::AgentBase.new

    CHAINABLE_CONFIG_CALLS.each_with_index do |call, i|
      assert_same agent, call.call(agent), "config call ##{i} must return self"
    end
  end
end

# =========================================================================
# Proxy URL tests
# =========================================================================
class AgentProxyUrlTest < Minitest::Test
  def test_proxy_url_from_env
    ENV['SWML_PROXY_URL_BASE'] = 'https://proxy.example.com'
    agent = SignalWire::AgentBase.new
    agent.define_tool(name: 'test', description: 'Test', parameters: {}, handler: nil) { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    url = ai['SWAIG']['defaults']['web_hook_url']

    assert_includes url, 'https://proxy.example.com'
  ensure
    ENV.delete('SWML_PROXY_URL_BASE')
  end

  def test_manual_set_proxy_url
    agent = SignalWire::AgentBase.new
    agent.manual_set_proxy_url('https://manual.example.com')
    agent.define_tool(name: 'test', description: 'Test', parameters: {}, handler: nil) { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    url = ai['SWAIG']['defaults']['web_hook_url']

    assert_includes url, 'https://manual.example.com'
  end
end

# =========================================================================
# SWAIG query params tests
# =========================================================================
class AgentSwaigQueryParamsTest < Minitest::Test
  def test_add_swaig_query_params
    agent = SignalWire::AgentBase.new(basic_auth: %w[u p])
    agent.add_swaig_query_params({ 'tenant' => 'acme' })
    agent.define_tool(name: 'test', description: 'Test', parameters: {}, handler: nil) { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    url = ai['SWAIG']['defaults']['web_hook_url']

    assert_includes url, 'tenant=acme'
  end

  def test_clear_swaig_query_params
    agent = SignalWire::AgentBase.new
    agent.add_swaig_query_params({ 'key' => 'val' })
    agent.clear_swaig_query_params
    agent.define_tool(name: 'test', description: 'Test', parameters: {}, handler: nil) { |_, _| }
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    url = ai['SWAIG']['defaults']['web_hook_url']

    refute_includes url, 'key=val'
  end
end

# =========================================================================
# DataMap integration test
# =========================================================================
class AgentDataMapTest < Minitest::Test
  include AgentRenderHelpers

  def weather_datamap
    SignalWire::DataMap.new('get_weather')
                       .purpose('Get weather')
                       .parameter('city', 'string', 'City name', required: true)
                       .webhook('GET', 'https://api.weather.com?q=${city}')
                       .output(SignalWire::Swaig::FunctionResult.new('Weather: ${response.temp}'))
  end

  def test_register_datamap_tool
    agent = SignalWire::AgentBase.new
    agent.register_swaig_function(weather_datamap.to_swaig_function)
    funcs = rendered_ai(agent)['SWAIG']['functions']
    weather = funcs.find { |f| f['function'] == 'get_weather' }

    assert weather
    assert weather.key?('data_map')
  end
end

# =========================================================================
# on_debug_event callback test
# =========================================================================
class AgentDebugEventTest < Minitest::Test
  include Rack::Test::Methods

  def app
    @agent = SignalWire::AgentBase.new(basic_auth: %w[u p])
    @received_event = nil
    @agent.on_debug_event(nil) do |event_type, data|
      @received_event = [event_type, data]
    end
    @agent.rack_app
  end

  def test_debug_event_dispatch
    header 'Authorization', "Basic #{['u:p'].pack('m0')}"
    header 'Content-Type', 'application/json'
    post '/debug_events', JSON.generate({ 'event_type' => 'llm_error', 'detail' => 'oops' })

    assert_equal 200, last_response.status
    assert_equal 'llm_error', @received_event[0]
    assert_equal 'oops', @received_event[1]['detail']
  end
end

# =========================================================================
# SIP username extraction tests
# =========================================================================
class AgentSipUsernameTest < Minitest::Test
  def test_extract_sip_username_basic
    assert_equal 'alice', SignalWire::AgentBase.extract_sip_username('sip:alice@example.com')
  end

  def test_extract_sips_username
    assert_equal 'bob', SignalWire::AgentBase.extract_sip_username('sips:bob@example.com')
  end

  def test_extract_without_scheme
    assert_equal 'carol', SignalWire::AgentBase.extract_sip_username('carol@example.com')
  end

  def test_extract_nil_returns_nil
    assert_nil SignalWire::AgentBase.extract_sip_username(nil)
  end

  def test_extract_empty_returns_nil
    assert_nil SignalWire::AgentBase.extract_sip_username('')
  end

  def test_extract_no_at_sign_returns_nil
    assert_nil SignalWire::AgentBase.extract_sip_username('sip:justuser')
  end

  def test_extract_empty_user_part_returns_nil
    assert_nil SignalWire::AgentBase.extract_sip_username('sip:@example.com')
  end

  def test_extract_from_request_to_field
    data = { 'to' => 'sip:alice@example.com' }

    assert_equal 'alice', SignalWire::AgentBase.extract_sip_username_from_request(data)
  end

  def test_extract_from_request_from_field
    data = { 'from' => 'sip:bob@example.com' }

    assert_equal 'bob', SignalWire::AgentBase.extract_sip_username_from_request(data)
  end

  def test_extract_from_request_sip_uri_field
    data = { 'sip_uri' => 'sip:carol@example.com' }

    assert_equal 'carol', SignalWire::AgentBase.extract_sip_username_from_request(data)
  end

  def test_extract_from_request_nested_call_to
    data = { 'call' => { 'to' => 'sip:dave@example.com' } }

    assert_equal 'dave', SignalWire::AgentBase.extract_sip_username_from_request(data)
  end

  def test_extract_from_request_nested_call_from
    data = { 'call' => { 'from' => 'sip:eve@example.com' } }

    assert_equal 'eve', SignalWire::AgentBase.extract_sip_username_from_request(data)
  end

  def test_extract_from_request_nil
    assert_nil SignalWire::AgentBase.extract_sip_username_from_request(nil)
  end

  def test_extract_from_request_empty
    assert_nil SignalWire::AgentBase.extract_sip_username_from_request({})
  end

  def test_extract_from_request_no_sip_fields
    data = { 'call_id' => 'abc-123', 'function' => 'test' }

    assert_nil SignalWire::AgentBase.extract_sip_username_from_request(data)
  end

  def test_extract_from_request_prefers_first_match
    data = { 'to' => 'sip:first@example.com', 'from' => 'sip:second@example.com' }

    assert_equal 'first', SignalWire::AgentBase.extract_sip_username_from_request(data)
  end
end

# =========================================================================
# Password not logged test
# =========================================================================
class AgentPasswordNotLoggedTest < Minitest::Test
  def test_password_not_in_log_output
    # Read the source file and verify password is redacted in log messages
    source = File.read(File.join(__dir__, '..', 'lib', 'signalwire', 'agent', 'agent_base.rb'))
    # The serve method should log [REDACTED] not the actual password
    assert_includes source, 'password: [REDACTED]'
    refute_match(/password: #\{pass\}/, source)
  end
end

# --- Identity / URL accessors (get_name, get_full_url) -------------------
class AgentIdentityAccessorsTest < Minitest::Test
  def test_get_name_returns_name
    agent = SignalWire::AgentBase.new(name: 'my_agent')

    assert_equal 'my_agent', agent.get_name
    assert_equal agent.name, agent.get_name
  end

  def test_get_name_default
    assert_equal 'agent', SignalWire::AgentBase.new.get_name
  end

  def test_get_full_url_default
    agent = SignalWire::AgentBase.new(host: '127.0.0.1', port: 8080, route: '/bot')

    assert_equal 'http://127.0.0.1:8080/bot', agent.get_full_url
  end

  def test_get_full_url_include_auth
    agent = SignalWire::AgentBase.new(host: 'h', port: 3000, route: '/', basic_auth: %w[u p])

    assert_equal 'http://u:p@h:3000/', agent.get_full_url(include_auth: true)
  end
end

# --- Idiomatic-accessor alias prototype (RUBY_ERGONOMICS_MIGRATION.md) ---
class AgentBaseIdiomaticAccessorsTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new(name: 'test')
  end

  # The Python-named originals still work (audit parity).
  def test_python_named_originals_still_work
    @agent.set_post_prompt('summarize the call')

    assert_equal 'summarize the call', @agent.get_post_prompt
  end

  # The idiomatic writer + reader pair (the showcase).
  def test_post_prompt_idiomatic_writer_and_reader
    @agent.post_prompt = 'summarize the call'

    assert_equal 'summarize the call', @agent.post_prompt
    # And it's the same underlying state the Python-named getter sees.
    assert_equal 'summarize the call', @agent.get_post_prompt
  end

  # Writer returns the assigned value (Ruby `=` semantics), not self.
  def test_writer_returns_assigned_value
    assert_equal 'x', (@agent.post_prompt = 'x')
  end

  # prompt_text is a symmetric raw reader/writer pair.
  def test_prompt_text_pair
    @agent.prompt_text = 'you are helpful'

    assert_equal 'you are helpful', @agent.prompt_text
    assert_equal 'you are helpful', @agent.get_raw_prompt
  end

  # prompt is a reader-only alias over the computed get_prompt.
  def test_prompt_reader_alias
    @agent.prompt_text = 'hello'

    assert_equal @agent.get_prompt, @agent.prompt
  end
end

# =========================================================================
# as_router: the "embed my routes in a host app" mountable-handler capability.
#
# Python parity: AgentBase.as_router() returns a HostAppRouter that a host app
# mounts. Ruby's idiomatic equivalent is a Rack app -- an object responding to
# #call(env) -- mountable via Rails/Sinatra `mount`/`map`. as_router returns the
# agent's rack_app (the same mountable unit), carrying this agent's routes
# (/, /swaig, /post_prompt, /health, /ready + routing callbacks).
# =========================================================================
class AgentAsRouterTest < Minitest::Test
  include Rack::Test::Methods
  include AgentRenderHelpers

  def build_agent
    agent = SignalWire::AgentBase.new(basic_auth: %w[testuser testpass])
    agent.set_prompt_text('Hello')
    # secure: false — this fixture exercises the AgentServer router, not the
    # `secure` token contract (see swaig_token_enforcement_test.rb).
    agent.define_tool(name: 'echo', description: 'Echo', parameters: {},
                      secure: false, handler: nil) do |args, _raw|
      SignalWire::Swaig::FunctionResult.new("Echo: #{args['msg']}")
    end
    agent
  end

  # Rack::Test drives the router returned by as_router (mounted at the root),
  # proving it is the mountable unit a host app would embed.
  def app
    @agent ||= build_agent
    @agent.as_router
  end

  def auth_header
    "Basic #{['testuser:testpass'].pack('m0')}"
  end

  # as_router must return a Rack-compatible app: an object responding to #call.
  def test_returns_rack_callable
    router = build_agent.as_router

    assert_respond_to router, :call, 'as_router must return a Rack app (responds to #call)'
  end

  # It is the same mountable unit as rack_app (Ruby's rack-mountable idiom for
  # HostAppRouter), so host-app mounting and direct serving share one handler.
  def test_is_the_rack_app
    agent = build_agent

    assert_same agent.rack_app, agent.as_router
  end

  # The router carries this agent's public (no-auth) route.
  def test_router_serves_health
    get '/health'

    assert_equal 200, last_response.status
    assert_equal 'healthy', JSON.parse(last_response.body)['status']
  end

  # The router carries the agent's authenticated SWML route (GET /).
  def test_router_serves_swml_root
    header 'Authorization', auth_header
    get '/'

    assert_equal 200, last_response.status
    assert_equal '1.0.0', JSON.parse(last_response.body)['version']
  end

  # The router carries the SWAIG dispatch route.
  def test_router_serves_swaig
    header 'Authorization', auth_header
    header 'Content-Type', 'application/json'
    post '/swaig', JSON.generate('function' => 'echo',
                                 'argument' => { 'parsed' => [{ 'msg' => 'hi' }] },
                                 'call_id' => 'call-1')

    assert_equal 200, last_response.status
    assert_equal 'Echo: hi', JSON.parse(last_response.body)['response']
  end
end
