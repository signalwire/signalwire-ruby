# frozen_string_literal: true

require 'minitest/autorun'
require 'json'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class SchemaUtilsTest < Minitest::Test
  def test_schema_loads
    schema = SignalWire::SWML::Schema.new
    assert schema.verb_count > 0
  end

  def test_known_verbs_valid
    schema = SignalWire::SWML::Schema.new
    %w[answer ai hangup play sleep connect record send_sms transfer].each do |v|
      assert schema.valid_verb?(v), "Expected verb '#{v}' to be valid"
    end
  end

  def test_invalid_verb_rejected
    schema = SignalWire::SWML::Schema.new
    refute schema.valid_verb?('not_a_verb')
    refute schema.valid_verb?('explode')
  end

  def test_verb_names_sorted
    schema = SignalWire::SWML::Schema.new
    names = schema.verb_names
    assert_equal names.sort, names
  end

  def test_get_verb_returns_definition
    schema = SignalWire::SWML::Schema.new
    defn = schema.get_verb('answer')
    assert_kind_of Hash, defn
    assert_equal 'answer', defn['name']
  end

  def test_get_verb_nil_for_unknown
    schema = SignalWire::SWML::Schema.new
    assert_nil schema.get_verb('nonexistent')
  end

  def test_singleton
    s1 = SignalWire::SWML.schema
    s2 = SignalWire::SWML.schema
    assert_same s1, s2
  end

  def test_parameter_normalisation
    agent = SignalWire::AgentBase.new
    agent.define_tool(
      name: 'test',
      description: 'Test',
      parameters: { 'name' => { 'type' => 'string', 'description' => 'Name' } }
    ) { |_, _| }

    tools = agent.define_tools
    params = tools[0]['parameters']
    assert_equal 'object', params['type']
    assert params['properties'].key?('name')
  end

  def test_empty_parameters_normalised
    agent = SignalWire::AgentBase.new
    agent.define_tool(name: 'test', description: 'Test', parameters: {}) { |_, _| }
    tools = agent.define_tools
    params = tools[0]['parameters']
    assert_equal 'object', params['type']
    assert_equal({}, params['properties'])
  end
end
