# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class ToolRegistryTest < Minitest::Test
  def setup
    @registry = SignalWire::Core::Agent::Tools::ToolRegistry.new
  end

  def test_define_tool_and_get
    @registry.define_tool(name: 'greet', description: 'Say hi',
                          parameters: { 'name' => { 'type' => 'string' } })
    fn = @registry.get_function('greet')

    refute_nil fn
    assert_equal 'greet', fn['function']
    assert_equal 'Say hi', fn['description']
  end

  def test_has_function
    @registry.define_tool(name: 'a', description: 'd')

    assert @registry.has_function('a')
    refute @registry.has_function('missing')
  end

  def test_get_function_missing_returns_nil
    assert_nil @registry.get_function('nope')
  end

  def test_define_tool_normalises_parameters_into_object_schema
    @registry.define_tool(name: 't', description: 'd',
                          parameters: { 'city' => { 'type' => 'string' } })
    schema = @registry.get_function('t')['parameters']

    assert_equal 'object', schema['type']
    assert_equal({ 'city' => { 'type' => 'string' } }, schema['properties'])
  end

  def test_define_tool_injects_required
    @registry.define_tool(name: 't', description: 'd',
                          parameters: { 'city' => { 'type' => 'string' } },
                          required: ['city'])
    schema = @registry.get_function('t')['parameters']

    assert_includes schema['required'], 'city'
  end

  def test_define_tool_optional_fields
    @registry.define_tool(name: 't', description: 'd',
                          wait_file: 'https://x/w.mp3', wait_file_loops: 2,
                          webhook_url: 'https://x/hook',
                          fillers: { 'en-US' => ['wait'] })
    fn = @registry.get_function('t')

    assert_equal 'https://x/w.mp3', fn['wait_file']
    assert_equal 2, fn['wait_file_loops']
    assert_equal 'https://x/hook', fn['webhook_url']
    assert_equal({ 'en-US' => ['wait'] }, fn['fillers'])
  end

  def test_define_tool_swaig_fields_merged
    @registry.define_tool(name: 't', description: 'd', swaig_fields: { 'meta_data' => { 'k' => 'v' } })

    assert_equal({ 'k' => 'v' }, @registry.get_function('t')['meta_data'])
  end

  def test_define_tool_duplicate_raises
    @registry.define_tool(name: 'dup', description: 'd')

    assert_raises(ArgumentError) { @registry.define_tool(name: 'dup', description: 'd2') }
  end

  def test_register_swaig_function
    @registry.register_swaig_function({ 'function' => 'weather', 'parameters' => {} })

    assert @registry.has_function('weather')
    assert_equal 'weather', @registry.get_function('weather')['function']
  end

  def test_register_swaig_function_symbol_keys
    @registry.register_swaig_function({ function: 'dm', parameters: {} })

    assert @registry.has_function('dm')
    assert @registry.get_function('dm').key?('function'), 'keys should be stringified'
  end

  def test_register_swaig_function_missing_name_raises
    assert_raises(ArgumentError) { @registry.register_swaig_function({ 'parameters' => {} }) }
  end

  def test_register_swaig_function_duplicate_raises
    @registry.register_swaig_function({ 'function' => 'x' })

    assert_raises(ArgumentError) { @registry.register_swaig_function({ 'function' => 'x' }) }
  end

  def test_get_all_functions_returns_copy
    @registry.define_tool(name: 'a', description: 'd')
    @registry.register_swaig_function({ 'function' => 'b' })
    all = @registry.get_all_functions

    assert_equal %w[a b], all.keys.sort
    # Mutating the returned Hash must not affect the registry.
    all.delete('a')

    assert @registry.has_function('a')
  end

  def test_remove_function
    @registry.define_tool(name: 'a', description: 'd')

    assert @registry.remove_function('a')
    refute @registry.has_function('a')
  end

  def test_remove_function_missing_returns_false
    refute @registry.remove_function('nope')
  end
end
