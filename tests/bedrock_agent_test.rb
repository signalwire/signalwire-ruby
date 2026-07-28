# frozen_string_literal: true

require 'minitest/autorun'
require 'json'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

# The amazon_bedrock verb object from a rendered BedrockAgent SWML doc.
module BedrockRenderHelpers
  def bedrock_verb(agent)
    main = agent.render_swml['sections']['main']
    main.find { |v| v.key?('amazon_bedrock') }['amazon_bedrock']
  end
end

class BedrockAgentTest < Minitest::Test
  include BedrockRenderHelpers

  def test_defaults
    agent = SignalWire::Agents::BedrockAgent.new

    assert_equal 'bedrock_agent', agent.name
    assert_equal '/bedrock', agent.route
  end

  def test_renders_amazon_bedrock_verb_not_ai
    agent = SignalWire::Agents::BedrockAgent.new
    agent.set_prompt_text('Hello')
    main = agent.render_swml['sections']['main']

    assert(main.any? { |v| v.key?('amazon_bedrock') }, 'expected amazon_bedrock verb')
    refute(main.any? { |v| v.key?('ai') }, 'ai verb must be transformed away')
  end

  def test_voice_and_inference_params_in_prompt
    agent = SignalWire::Agents::BedrockAgent.new(voice_id: 'joanna', temperature: 0.3, top_p: 0.8)
    agent.set_prompt_text('Hi')
    prompt = bedrock_verb(agent)['prompt']

    assert_equal 'joanna', prompt['voice_id']
    assert_in_delta(0.3, prompt['temperature'])
    assert_in_delta(0.8, prompt['top_p'])
  end

  def test_system_prompt_constructor_arg
    agent = SignalWire::Agents::BedrockAgent.new(system_prompt: 'You are helpful')

    assert_equal 'You are helpful', bedrock_verb(agent)['prompt']['text']
  end

  def test_bedrock_object_keys_present_with_tool_and_post_prompt
    agent = SignalWire::Agents::BedrockAgent.new
    agent.set_prompt_text('Hi')
    agent.define_tool(name: 't', description: 'd', parameters: {}, handler: nil) { |_a, _r| {} }
    agent.set_post_prompt('summarize')
    ab = bedrock_verb(agent)

    assert_equal %w[SWAIG post_prompt post_prompt_url prompt], ab.keys.sort
  end

  def test_nil_keys_dropped
    agent = SignalWire::Agents::BedrockAgent.new
    agent.set_prompt_text('Hi')
    ab = bedrock_verb(agent)

    # No post_prompt set → key must be absent (nil-dropped), not nil-valued.
    refute ab.key?('post_prompt')
    refute ab.key?('post_prompt_url')
  end

  def test_set_voice
    agent = SignalWire::Agents::BedrockAgent.new
    agent.set_prompt_text('Hi')
    agent.set_voice('stephen')

    assert_equal 'stephen', bedrock_verb(agent)['prompt']['voice_id']
  end

  def test_set_inference_params_partial_update
    agent = SignalWire::Agents::BedrockAgent.new(temperature: 0.7, top_p: 0.9)
    agent.set_prompt_text('Hi')
    agent.set_inference_params(temperature: 0.2)
    prompt = bedrock_verb(agent)['prompt']

    assert_in_delta(0.2, prompt['temperature'])
    assert_in_delta(0.9, prompt['top_p'], 0.001, 'top_p should be unchanged')
  end

  def test_set_llm_temperature_redirects_to_inference
    agent = SignalWire::Agents::BedrockAgent.new
    agent.set_prompt_text('Hi')
    agent.set_llm_temperature(0.42)

    assert_in_delta(0.42, bedrock_verb(agent)['prompt']['temperature'])
  end

  def test_set_llm_model_is_noop_returns_self
    agent = SignalWire::Agents::BedrockAgent.new

    assert_same agent, agent.set_llm_model('anthropic.claude')
  end

  def test_set_prompt_llm_params_noop_returns_self
    agent = SignalWire::Agents::BedrockAgent.new

    assert_same agent, agent.set_prompt_llm_params(temperature: 0.5)
  end

  def test_set_post_prompt_llm_params_noop_returns_self
    agent = SignalWire::Agents::BedrockAgent.new

    assert_same agent, agent.set_post_prompt_llm_params(model: 'gpt-4o')
  end

  def test_text_model_only_prompt_keys_stripped
    agent = SignalWire::Agents::BedrockAgent.new
    agent.set_prompt_text('Hi')
    # Inject a text-model-only param into the prompt config via llm params.
    # These keys must not survive into the bedrock prompt object.
    agent.instance_variable_get(:@prompt_llm_params)['presence_penalty'] = 0.5
    prompt = bedrock_verb(agent)['prompt']

    refute prompt.key?('presence_penalty')
    assert prompt.key?('text')
  end

  def test_inspect_and_to_s_representation
    agent = SignalWire::Agents::BedrockAgent.new(name: 'myb', voice_id: 'joanna')
    expected = "BedrockAgent(name='myb', route='/bedrock', voice='joanna')"

    assert_equal expected, agent.inspect
    assert_equal expected, agent.to_s
  end

  def test_is_agent_base_subclass
    agent = SignalWire::Agents::BedrockAgent.new

    assert_kind_of SignalWire::AgentBase, agent
  end
end
