# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/signalwire/datamap/data_map'
require_relative '../lib/signalwire/swaig/function_result'

class DataMapTest < Minitest::Test
  FR = SignalWire::Swaig::FunctionResult
  DM = SignalWire::DataMap

  # ----------------------------------------------------------------
  # Basic creation and fluent building
  # ----------------------------------------------------------------

  def test_creation_and_fluent_building
    dm = DM.new('test_func')
           .purpose('A test function')
           .parameter('city', 'string', 'City name', required: true)
           .parameter('units', 'string', 'Temperature units', required: false, enum: %w[C F])
           .webhook('GET', 'https://api.example.com/weather?q=${city}&units=${units}')
           .output(FR.new('Temperature in ${city}: ${response.temp}'))

    assert_equal 'test_func', dm.function_name

    swaig = dm.to_swaig_function
    assert_equal 'test_func', swaig['function']
    assert_equal 'A test function', swaig['description']
  end

  # ----------------------------------------------------------------
  # description is alias for purpose
  # ----------------------------------------------------------------

  def test_description_alias
    dm = DM.new('func').description('My description')
    swaig = dm.to_swaig_function
    assert_equal 'My description', swaig['description']
  end

  # ----------------------------------------------------------------
  # Default description when purpose is empty
  # ----------------------------------------------------------------

  def test_default_description
    dm = DM.new('do_thing')
    swaig = dm.to_swaig_function
    assert_equal 'Execute do_thing', swaig['description']
  end

  # ----------------------------------------------------------------
  # Parameter with enum
  # ----------------------------------------------------------------

  def test_parameter_with_enum
    dm = DM.new('func')
           .parameter('color', 'string', 'Color choice', enum: %w[red blue green])

    swaig = dm.to_swaig_function
    props = swaig['parameters']['properties']
    assert_equal %w[red blue green], props['color']['enum']
    assert_equal 'string', props['color']['type']
    assert_equal 'Color choice', props['color']['description']
  end

  # ----------------------------------------------------------------
  # Parameter without enum
  # ----------------------------------------------------------------

  def test_parameter_without_enum
    dm = DM.new('func')
           .parameter('query', 'string', 'Search query', required: true)

    swaig = dm.to_swaig_function
    props = swaig['parameters']['properties']
    refute props['query'].key?('enum')
    assert_equal ['query'], swaig['parameters']['required']
  end

  # ----------------------------------------------------------------
  # No parameters produces empty properties
  # ----------------------------------------------------------------

  def test_no_parameters
    dm = DM.new('func').purpose('test')
    swaig = dm.to_swaig_function
    assert_equal({ "type" => "object", "properties" => {} }, swaig['parameters'])
  end

  # ----------------------------------------------------------------
  # Webhook configuration
  # ----------------------------------------------------------------

  def test_webhook_configuration
    dm = DM.new('func')
           .webhook('POST', 'https://api.example.com/search',
                    headers: { 'Authorization' => 'Bearer TOKEN' },
                    form_param: 'payload',
                    input_args_as_params: true,
                    require_args: %w[query])
           .output(FR.new('done'))

    swaig = dm.to_swaig_function
    wh = swaig['data_map']['webhooks'].first

    assert_equal 'POST', wh['method']
    assert_equal 'https://api.example.com/search', wh['url']
    assert_equal({ 'Authorization' => 'Bearer TOKEN' }, wh['headers'])
    assert_equal 'payload', wh['form_param']
    assert_equal true, wh['input_args_as_params']
    assert_equal %w[query], wh['require_args']
  end

  # ----------------------------------------------------------------
  # Webhook body and params
  # ----------------------------------------------------------------

  def test_webhook_body_and_params
    dm = DM.new('func')
           .webhook('POST', 'https://example.com')
           .body({ 'query' => '${args.q}' })
           .params({ 'limit' => 10 })
           .output(FR.new('ok'))

    wh = dm.to_swaig_function['data_map']['webhooks'].first
    assert_equal({ 'query' => '${args.q}' }, wh['body'])
    assert_equal({ 'limit' => 10 }, wh['params'])
  end

  # ----------------------------------------------------------------
  # body/params/output/foreach without webhook raises
  # ----------------------------------------------------------------

  def test_body_without_webhook_raises
    dm = DM.new('func')
    assert_raises(ArgumentError) { dm.body({}) }
  end

  def test_params_without_webhook_raises
    dm = DM.new('func')
    assert_raises(ArgumentError) { dm.params({}) }
  end

  def test_output_without_webhook_raises
    dm = DM.new('func')
    assert_raises(ArgumentError) { dm.output(FR.new('x')) }
  end

  def test_foreach_without_webhook_raises
    dm = DM.new('func')
    assert_raises(ArgumentError) { dm.foreach({ "input_key" => "r", "output_key" => "o", "append" => "t" }) }
  end

  def test_webhook_expressions_without_webhook_raises
    dm = DM.new('func')
    assert_raises(ArgumentError) { dm.webhook_expressions([]) }
  end

  # ----------------------------------------------------------------
  # Expression with and without nomatch
  # ----------------------------------------------------------------

  def test_expression_basic
    dm = DM.new('ctrl')
           .expression('${args.cmd}', 'start.*', FR.new('Starting'))

    swaig = dm.to_swaig_function
    exprs = swaig['data_map']['expressions']
    assert_equal 1, exprs.size
    assert_equal '${args.cmd}', exprs[0]['string']
    assert_equal 'start.*', exprs[0]['pattern']
    assert_equal({ 'response' => 'Starting' }, exprs[0]['output'])
    refute exprs[0].key?('nomatch-output')
  end

  def test_expression_with_nomatch
    dm = DM.new('ctrl')
           .expression('${args.cmd}', 'yes',
                       FR.new('Confirmed'),
                       nomatch_output: FR.new('Not understood'))

    exprs = dm.to_swaig_function['data_map']['expressions']
    assert_equal({ 'response' => 'Confirmed' }, exprs[0]['output'])
    assert_equal({ 'response' => 'Not understood' }, exprs[0]['nomatch-output'])
  end

  # ----------------------------------------------------------------
  # Expression with Regexp
  # ----------------------------------------------------------------

  def test_expression_with_regexp
    dm = DM.new('ctrl')
           .expression('${args.cmd}', /stop\s+now/, FR.new('Stopping'))

    exprs = dm.to_swaig_function['data_map']['expressions']
    assert_equal 'stop\s+now', exprs[0]['pattern']
  end

  # ----------------------------------------------------------------
  # Webhook expressions
  # ----------------------------------------------------------------

  def test_webhook_expressions
    dm = DM.new('func')
           .webhook('GET', 'https://example.com')
           .webhook_expressions([{ "string" => "${response.status}", "pattern" => "ok" }])
           .output(FR.new('done'))

    wh = dm.to_swaig_function['data_map']['webhooks'].first
    assert_equal 1, wh['expressions'].size
  end

  # ----------------------------------------------------------------
  # to_swaig_function full serialization
  # ----------------------------------------------------------------

  def test_to_swaig_function_serialization
    dm = DM.new('search')
           .purpose('Search documents')
           .parameter('query', 'string', 'Search query', required: true)
           .parameter('limit', 'number', 'Max results')
           .webhook('POST', 'https://api.docs.com/search',
                    headers: { 'Authorization' => 'Bearer TOKEN' })
           .body({ 'query' => '${query}', 'limit' => 3 })
           .output(FR.new('Found: ${response.results[0].title}'))

    swaig = dm.to_swaig_function
    assert_equal 'search', swaig['function']
    assert_equal 'Search documents', swaig['description']
    assert_equal 'object', swaig['parameters']['type']
    assert_includes swaig['parameters']['required'], 'query'
    refute_includes swaig['parameters']['required'], 'limit'
    assert swaig['data_map'].key?('webhooks')
    assert_equal 1, swaig['data_map']['webhooks'].size
  end

  # ----------------------------------------------------------------
  # Multiple webhooks with fallback
  # ----------------------------------------------------------------

  def test_multiple_webhooks_with_fallback
    dm = DM.new('multi')
           .purpose('Multi source search')
           .webhook('GET', 'https://primary.com/search')
           .output(FR.new('Primary: ${response.title}'))
           .webhook('GET', 'https://fallback.com/search')
           .output(FR.new('Fallback: ${response.title}'))
           .fallback_output(FR.new('All sources unavailable'))

    swaig = dm.to_swaig_function
    assert_equal 2, swaig['data_map']['webhooks'].size
    assert_equal({ 'response' => 'All sources unavailable' }, swaig['data_map']['output'])
  end

  # ----------------------------------------------------------------
  # foreach
  # ----------------------------------------------------------------

  def test_foreach
    dm = DM.new('func')
           .webhook('POST', 'https://example.com')
           .foreach({ "input_key" => "results", "output_key" => "formatted", "max" => 3, "append" => "${this.title}\n" })
           .output(FR.new('ok'))

    wh = dm.to_swaig_function['data_map']['webhooks'].first
    assert_equal 'results', wh['foreach']['input_key']
    assert_equal 3, wh['foreach']['max']
  end

  def test_foreach_missing_keys
    dm = DM.new('func').webhook('GET', 'https://example.com')
    assert_raises(ArgumentError) { dm.foreach({ "input_key" => "x" }) }
  end

  def test_foreach_must_be_hash
    dm = DM.new('func').webhook('GET', 'https://example.com')
    assert_raises(ArgumentError) { dm.foreach("not a hash") }
  end

  # ----------------------------------------------------------------
  # Error keys
  # ----------------------------------------------------------------

  def test_error_keys_on_webhook
    dm = DM.new('func')
           .webhook('GET', 'https://example.com')
           .error_keys(%w[error message])
           .output(FR.new('ok'))

    wh = dm.to_swaig_function['data_map']['webhooks'].first
    assert_equal %w[error message], wh['error_keys']
  end

  def test_error_keys_global_when_no_webhook
    dm = DM.new('func')
           .error_keys(%w[error])

    swaig = dm.to_swaig_function
    assert_equal %w[error], swaig['data_map']['error_keys']
  end

  def test_global_error_keys
    dm = DM.new('func')
           .global_error_keys(%w[err])

    swaig = dm.to_swaig_function
    assert_equal %w[err], swaig['data_map']['error_keys']
  end

  # ----------------------------------------------------------------
  # Output and fallback_output
  # ----------------------------------------------------------------

  def test_output_and_fallback
    dm = DM.new('func')
           .webhook('GET', 'https://example.com')
           .output(FR.new('Result: ${response.data}'))
           .fallback_output(FR.new('Service unavailable'))

    swaig = dm.to_swaig_function
    assert_equal({ 'response' => 'Result: ${response.data}' },
                 swaig['data_map']['webhooks'].first['output'])
    assert_equal({ 'response' => 'Service unavailable' },
                 swaig['data_map']['output'])
  end

  # ----------------------------------------------------------------
  # Output with actions
  # ----------------------------------------------------------------

  def test_output_with_actions
    result = FR.new('Transferring').add_action('transfer', { 'dest' => '+1555' })
    dm = DM.new('func')
           .webhook('GET', 'https://example.com')
           .output(result)

    wh = dm.to_swaig_function['data_map']['webhooks'].first
    assert_equal 'Transferring', wh['output']['response']
    assert_equal [{ 'transfer' => { 'dest' => '+1555' } }], wh['output']['action']
  end

  # ----------------------------------------------------------------
  # create_simple_api_tool
  # ----------------------------------------------------------------

  def test_create_simple_api_tool
    dm = DM.create_simple_api_tool(
      name: 'get_weather',
      url: 'https://api.weather.com/v1?q=${location}',
      response_template: 'Weather: ${response.temp}',
      parameters: {
        'location' => { 'type' => 'string', 'description' => 'City', 'required' => true }
      },
      method: 'GET',
      headers: { 'X-Key' => 'abc' },
      error_keys: %w[error]
    )

    swaig = dm.to_swaig_function
    assert_equal 'get_weather', swaig['function']
    assert_includes swaig['parameters']['required'], 'location'
    assert_equal %w[error], swaig['data_map']['webhooks'].first['error_keys']
    assert_equal 'Weather: ${response.temp}', swaig['data_map']['webhooks'].first['output']['response']
  end

  def test_create_simple_api_tool_with_body
    dm = DM.create_simple_api_tool(
      name: 'post_data',
      url: 'https://example.com/api',
      response_template: 'Done: ${response.id}',
      method: 'POST',
      body: { 'data' => '${args.payload}' }
    )

    wh = dm.to_swaig_function['data_map']['webhooks'].first
    assert_equal 'POST', wh['method']
    assert_equal({ 'data' => '${args.payload}' }, wh['body'])
  end

  def test_create_simple_api_tool_minimal
    dm = DM.create_simple_api_tool(
      name: 'ping',
      url: 'https://example.com/ping',
      response_template: 'pong'
    )

    swaig = dm.to_swaig_function
    assert_equal 'ping', swaig['function']
    assert_equal({ "type" => "object", "properties" => {} }, swaig['parameters'])
  end

  # ----------------------------------------------------------------
  # create_expression_tool
  # ----------------------------------------------------------------

  def test_create_expression_tool
    dm = DM.create_expression_tool(
      name: 'file_control',
      patterns: {
        '${args.command}' => ['start.*', FR.new('Starting playback')],
        '${args.command2}' => ['stop.*', FR.new('Stopping')]
      },
      parameters: {
        'command'  => { 'type' => 'string', 'description' => 'Playback command', 'required' => true },
        'command2' => { 'type' => 'string', 'description' => 'Other command' }
      }
    )

    swaig = dm.to_swaig_function
    assert_equal 'file_control', swaig['function']
    exprs = swaig['data_map']['expressions']
    assert_equal 2, exprs.size
    assert_equal 'start.*', exprs[0]['pattern']
    assert_equal 'stop.*', exprs[1]['pattern']
    assert_includes swaig['parameters']['required'], 'command'
    refute_includes swaig['parameters']['required'], 'command2'
  end

  def test_create_expression_tool_no_params
    dm = DM.create_expression_tool(
      name: 'echo',
      patterns: { '${args.msg}' => ['.*', FR.new('Echo: ${args.msg}')] }
    )

    swaig = dm.to_swaig_function
    assert_equal({ "type" => "object", "properties" => {} }, swaig['parameters'])
    assert_equal 1, swaig['data_map']['expressions'].size
  end

  # ----------------------------------------------------------------
  # Fluent chaining returns self
  # ----------------------------------------------------------------

  def test_fluent_chaining_returns_self
    dm = DM.new('func')
    assert_same dm, dm.purpose('test')
    assert_same dm, dm.description('test')
    assert_same dm, dm.parameter('x', 'string', 'desc')
    assert_same dm, dm.expression('${x}', 'pat', FR.new('y'))
    assert_same dm, dm.webhook('GET', 'https://example.com')
    assert_same dm, dm.body({})
    assert_same dm, dm.params({})
    assert_same dm, dm.foreach({ "input_key" => "a", "output_key" => "b", "append" => "c" })
    assert_same dm, dm.output(FR.new('ok'))
    assert_same dm, dm.fallback_output(FR.new('fail'))
    assert_same dm, dm.error_keys(%w[e])
    assert_same dm, dm.global_error_keys(%w[e])
    assert_same dm, dm.webhook_expressions([])
  end
end
