# frozen_string_literal: true

require 'minitest/autorun'

ENV['SIGNALWIRE_LOG_MODE'] = 'off'

require_relative '../lib/signalwire'

class ToolRegistrationTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_define_tool_with_block
    @agent.define_tool(
      name: 'greet',
      description: 'Say hello',
      parameters: { 'name' => { 'type' => 'string', 'description' => 'Name' } }
    ) do |args, _raw|
      SignalWire::Swaig::FunctionResult.new("Hello, #{args['name']}!")
    end

    tools = @agent.define_tools

    assert_equal 1, tools.length
    assert_equal 'greet', tools[0]['function']
    assert_equal 'Say hello', tools[0]['description']
  end

  def test_define_tool_returns_self
    result = @agent.define_tool(name: 'x', description: 'x') { |_, _| }

    assert_same @agent, result
  end

  def test_define_multiple_tools
    3.times do |i|
      @agent.define_tool(name: "tool_#{i}", description: "Tool #{i}") { |_, _| }
    end

    assert_equal 3, @agent.define_tools.length
  end

  def test_tool_with_fillers
    @agent.define_tool(
      name: 'slow_op',
      description: 'Slow operation',
      fillers: { 'en-US' => ['Please wait...', 'Working on it...'] }
    ) { |_, _| SignalWire::Swaig::FunctionResult.new('Done') }

    tools = @agent.define_tools

    assert_equal({ 'en-US' => ['Please wait...', 'Working on it...'] }, tools[0]['fillers'])
  end
end

class ToolDispatchTest < Minitest::Test
  def setup
    @agent = SignalWire::AgentBase.new
  end

  def test_on_function_call_dispatch
    @agent.define_tool(
      name: 'echo',
      description: 'Echo back',
      parameters: {}
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

  def test_on_function_call_error_handling
    @agent.define_tool(name: 'bad', description: 'Raises') do |_, _|
      raise 'intentional error'
    end

    result = @agent.on_function_call('bad', {}, {})

    assert_includes result['response'], 'intentional error'
  end
end

class DataMapToolRegistrationTest < Minitest::Test
  def test_register_swaig_function
    agent = SignalWire::AgentBase.new
    dm_func = {
      'function' => 'weather',
      'description' => 'Get weather',
      'parameters' => { 'type' => 'object', 'properties' => {} },
      'data_map' => { 'webhooks' => [] }
    }
    agent.register_swaig_function(dm_func)
    tools = agent.define_tools

    assert_equal 1, tools.length
    assert_equal 'weather', tools[0]['function']
    assert tools[0].key?('data_map')
  end

  def test_register_swaig_function_returns_self
    agent = SignalWire::AgentBase.new
    result = agent.register_swaig_function({ 'function' => 'x' })

    assert_same agent, result
  end

  def test_register_datamap_tool
    agent = SignalWire::AgentBase.new
    dm = SignalWire::DataMap.new('get_weather')
                            .purpose('Get weather')
                            .parameter('city', 'string', 'City name', required: true)
                            .webhook('GET', 'https://api.weather.com?q=${city}')
                            .output(SignalWire::Swaig::FunctionResult.new('Weather: ${response.temp}'))

    agent.register_swaig_function(dm.to_swaig_function)
    swml = agent.render_swml
    ai = swml['sections']['main'].find { |v| v.key?('ai') }['ai']
    funcs = ai['SWAIG']['functions']
    weather = funcs.find { |f| f['function'] == 'get_weather' }

    assert weather
    assert weather.key?('data_map')
  end
end

class DefineToolsOrderingTest < Minitest::Test
  def test_tools_appear_before_swaig_functions
    agent = SignalWire::AgentBase.new
    agent.define_tool(name: 'tool_a', description: 'A') { |_, _| }
    agent.register_swaig_function({ 'function' => 'dm_b', 'description' => 'B' })
    agent.define_tool(name: 'tool_c', description: 'C') { |_, _| }

    tools = agent.define_tools
    names = tools.map { |t| t['function'] }
    # Tool definitions come before swaig functions
    assert_equal %w[tool_a tool_c dm_b], names
  end
end
