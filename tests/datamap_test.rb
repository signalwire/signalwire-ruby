# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/signalwire/datamap/data_map'
require_relative '../lib/signalwire/swaig/function_result'

# Shared short aliases for the DataMap test classes (split so no single
# Minitest class grows unbounded).
module DataMapTestAliases
  FR = SignalWire::Swaig::FunctionResult
  DM = SignalWire::DataMap

  # The ten properties schema.json $defs/Webhook permits, under
  # +unevaluatedProperties: {"not": {}}+ — everything else is forbidden.
  WEBHOOK_SCHEMA_KEYS = %w[error_keys expressions foreach headers input_args_as_params
                           method output params require_args url].freeze
end

class DataMapTest < Minitest::Test
  include DataMapTestAliases

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

    assert_equal({ 'type' => 'object', 'properties' => {} }, swaig['parameters'])
  end

  # ----------------------------------------------------------------
  # Webhook configuration
  # ----------------------------------------------------------------

  def configured_webhook
    DM.new('func')
      .webhook('POST', 'https://api.example.com/search',
               headers: { 'Authorization' => 'Bearer TOKEN' },
               form_param: 'payload',
               input_args_as_params: true,
               require_args: %w[query])
      .output(FR.new('done'))
      .to_swaig_function['data_map']['webhooks'].first
  end

  def test_webhook_configuration
    wh = configured_webhook

    assert_equal 'POST', wh['method']
    assert_equal 'https://api.example.com/search', wh['url']
    assert_equal({ 'Authorization' => 'Bearer TOKEN' }, wh['headers'])
    assert_equal 'payload', wh['form_param']
    assert wh['input_args_as_params']
    assert_equal %w[query], wh['require_args']
  end

  # ----------------------------------------------------------------
  # Webhook params
  # ----------------------------------------------------------------

  # Was +test_webhook_body_and_params+, which called +body+ AND +params+ and then
  # asserted +wh['body']+ — pinning a schema-forbidden key as correct. It now
  # asserts only the contract key and that +body+ is absent.
  def test_webhook_params
    dm = DM.new('func')
           .webhook('POST', 'https://example.com')
           .params({ 'query' => '${args.q}', 'limit' => 10 })
           .output(FR.new('ok'))

    wh = dm.to_swaig_function['data_map']['webhooks'].first

    assert_equal({ 'query' => '${args.q}', 'limit' => 10 }, wh['params'])
    refute wh.key?('body')
  end

  # ----------------------------------------------------------------
  # params/output/foreach without webhook raises
  # ----------------------------------------------------------------

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
    assert_raises(ArgumentError) { dm.foreach({ 'input_key' => 'r', 'output_key' => 'o', 'append' => 't' }) }
  end

  def test_webhook_expressions_without_webhook_raises
    dm = DM.new('func')
    assert_raises(ArgumentError) { dm.webhook_expressions([]) }
  end
end

# Expression / webhook-expression builder behaviors.
class DataMapExpressionTest < Minitest::Test
  include DataMapTestAliases

  def test_expression_basic
    dm = DM.new('ctrl')
           .expression('${args.cmd}', 'start.*', FR.new('Starting'))

    exprs = dm.to_swaig_function['data_map']['expressions']
    expr = exprs[0]

    assert_equal 1, exprs.size
    expected = { 'string' => '${args.cmd}', 'pattern' => 'start.*', 'output' => { 'response' => 'Starting' } }

    assert_equal expected, expr
    refute expr.key?('nomatch-output')
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
           .webhook_expressions([{ 'string' => '${response.status}', 'pattern' => 'ok' }])
           .output(FR.new('done'))

    wh = dm.to_swaig_function['data_map']['webhooks'].first

    assert_equal 1, wh['expressions'].size
  end

  # ----------------------------------------------------------------
  # to_swaig_function full serialization
  # ----------------------------------------------------------------

  def search_tool_swaig
    DM.new('search')
      .purpose('Search documents')
      .parameter('query', 'string', 'Search query', required: true)
      .parameter('limit', 'number', 'Max results')
      .webhook('POST', 'https://api.docs.com/search',
               headers: { 'Authorization' => 'Bearer TOKEN' })
      .params({ 'query' => '${query}', 'limit' => 3 })
      .output(FR.new('Found: ${response.results[0].title}'))
      .to_swaig_function
  end

  def test_to_swaig_function_serialization
    swaig = search_tool_swaig
    required = swaig['parameters']['required']

    assert_equal 'search', swaig['function']
    assert_equal 'Search documents', swaig['description']
    assert_equal 'object', swaig['parameters']['type']
    assert_includes required, 'query'
    refute_includes required, 'limit'
    assert_equal 1, swaig['data_map']['webhooks'].size
  end

  # ----------------------------------------------------------------
  # Multiple webhooks with fallback
  # ----------------------------------------------------------------

  def multi_webhook_swaig
    DM.new('multi')
      .purpose('Multi source search')
      .webhook('GET', 'https://primary.com/search')
      .output(FR.new('Primary: ${response.title}'))
      .webhook('GET', 'https://fallback.com/search')
      .output(FR.new('Fallback: ${response.title}'))
      .fallback_output(FR.new('All sources unavailable'))
      .to_swaig_function
  end

  def test_multiple_webhooks_with_fallback
    data_map = multi_webhook_swaig['data_map']

    assert_equal 2, data_map['webhooks'].size
    assert_equal({ 'response' => 'All sources unavailable' }, data_map['output'])
  end
end

# foreach / error_keys / output behaviors.
class DataMapOutputTest < Minitest::Test
  include DataMapTestAliases

  def test_foreach
    dm = DM.new('func')
           .webhook('POST', 'https://example.com')
           .foreach({ 'input_key' => 'results', 'output_key' => 'formatted', 'max' => 3,
                      'append' => "${this.title}\n" })
           .output(FR.new('ok'))

    wh = dm.to_swaig_function['data_map']['webhooks'].first

    assert_equal 'results', wh['foreach']['input_key']
    assert_equal 3, wh['foreach']['max']
  end

  def test_foreach_missing_keys
    dm = DM.new('func').webhook('GET', 'https://example.com')
    assert_raises(ArgumentError) { dm.foreach({ 'input_key' => 'x' }) }
  end

  def test_foreach_must_be_hash
    dm = DM.new('func').webhook('GET', 'https://example.com')
    assert_raises(ArgumentError) { dm.foreach('not a hash') }
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
end

# Factory helpers: create_simple_api_tool / create_expression_tool.
class DataMapFactoryTest < Minitest::Test
  include DataMapTestAliases

  def weather_tool_swaig
    params = { 'location' => { 'type' => 'string', 'description' => 'City', 'required' => true } }
    DM.create_simple_api_tool(
      name: 'get_weather', url: 'https://api.weather.com/v1?q=${location}',
      response_template: 'Weather: ${response.temp}', parameters: params,
      method: 'GET', headers: { 'X-Key' => 'abc' }, error_keys: %w[error]
    ).to_swaig_function
  end

  def test_create_simple_api_tool
    swaig = weather_tool_swaig
    wh = swaig['data_map']['webhooks'].first

    assert_equal 'get_weather', swaig['function']
    assert_includes swaig['parameters']['required'], 'location'
    assert_equal %w[error], wh['error_keys']
    assert_equal 'Weather: ${response.temp}', wh['output']['response']
  end

  # +create_simple_api_tool+ has no +body:+ keyword.
  #
  # +body+ is not a valid webhook key: porting-sdk/schema.json $defs/Webhook
  # declares exactly ten properties (error_keys, expressions, foreach, headers,
  # input_args_as_params, method, output, params, require_args, url) under
  # +unevaluatedProperties: {"not": {}}+, and neither engine reader
  # (mod_openai/actions.c parse_webhook, mod_openai/bedrock.c
  # bedrock_parse_webhook) looks up "body". Accepting the argument and
  # discarding it into an unread key silently lost the caller's data.
  def test_create_simple_api_tool_rejects_body
    assert_raises(ArgumentError) do
      DM.create_simple_api_tool(
        name: 'post_data',
        url: 'https://example.com/api',
        response_template: 'Done: ${response.id}',
        method: 'POST',
        body: { 'data' => '${args.payload}' }
      )
    end
  end

  # The webhook a POST-shaped +create_simple_api_tool+ emits.
  def post_tool_webhook
    DM.create_simple_api_tool(
      name: 'post_data', url: 'https://example.com/api',
      response_template: 'Done: ${response.id}',
      parameters: { 'payload' => { 'type' => 'string', 'description' => 'Payload' } },
      method: 'POST', headers: { 'Authorization' => 'Bearer TOKEN' }, error_keys: %w[error]
    ).to_swaig_function['data_map']['webhooks'].first
  end

  # The EMITTED webhook payload carries no +body+ key.
  def test_create_simple_api_tool_emits_no_body_key
    wh = post_tool_webhook

    assert_equal 'POST', wh['method']
    refute_includes wh.keys, 'body', "webhook carries a body key: #{wh.inspect}"
  end

  # Every emitted webhook key is one schema.json $defs/Webhook permits.
  def test_create_simple_api_tool_emits_only_schema_keys
    extra = post_tool_webhook.keys - WEBHOOK_SCHEMA_KEYS

    assert_empty extra, "webhook has keys outside schema.json $defs/Webhook: #{extra.sort.inspect}"
  end

  def test_create_simple_api_tool_minimal
    dm = DM.create_simple_api_tool(
      name: 'ping',
      url: 'https://example.com/ping',
      response_template: 'pong'
    )

    swaig = dm.to_swaig_function

    assert_equal 'ping', swaig['function']
    assert_equal({ 'type' => 'object', 'properties' => {} }, swaig['parameters'])
  end

  # ----------------------------------------------------------------
  # create_expression_tool
  # ----------------------------------------------------------------

  def file_control_tool_swaig
    patterns = {
      '${args.command}' => ['start.*', FR.new('Starting playback')],
      '${args.command2}' => ['stop.*', FR.new('Stopping')]
    }
    params = {
      'command' => { 'type' => 'string', 'description' => 'Playback command', 'required' => true },
      'command2' => { 'type' => 'string', 'description' => 'Other command' }
    }
    DM.create_expression_tool(name: 'file_control', patterns: patterns, parameters: params).to_swaig_function
  end

  def test_create_expression_tool
    swaig = file_control_tool_swaig
    exprs = swaig['data_map']['expressions']
    required = swaig['parameters']['required']

    assert_equal 'file_control', swaig['function']
    assert_equal(%w[start.* stop.*], exprs.map { |e| e['pattern'] })
    assert_includes required, 'command'
    refute_includes required, 'command2'
  end

  def test_create_expression_tool_no_params
    dm = DM.create_expression_tool(
      name: 'echo',
      patterns: { '${args.msg}' => ['.*', FR.new('Echo: ${args.msg}')] }
    )

    swaig = dm.to_swaig_function

    assert_equal({ 'type' => 'object', 'properties' => {} }, swaig['parameters'])
    assert_equal 1, swaig['data_map']['expressions'].size
  end

  # ----------------------------------------------------------------
  # Fluent chaining returns self
  # ----------------------------------------------------------------

  # Each entry is [method_name, *args]; every fluent builder method must
  # return the same instance so calls can be chained.
  def fluent_calls
    [
      [:purpose, 'test'], [:description, 'test'], [:parameter, 'x', 'string', 'desc'],
      [:expression, '${x}', 'pat', FR.new('y')], [:webhook, 'GET', 'https://example.com'],
      [:params, {}],
      [:foreach, { 'input_key' => 'a', 'output_key' => 'b', 'append' => 'c' }],
      [:output, FR.new('ok')], [:fallback_output, FR.new('fail')],
      [:error_keys, %w[e]], [:global_error_keys, %w[e]], [:webhook_expressions, []]
    ]
  end

  def test_fluent_chaining_returns_self
    dm = DM.new('func')

    fluent_calls.each do |meth, *args|
      assert_same dm, dm.public_send(meth, *args), "#{meth} must return self for chaining"
    end
  end
end

# +DataMap#body+ is GONE — the key it wrote is invalid, not merely ignored.
#
# Owner-ruled 2026-07-29, extending the earlier ruling ("if the server doesn't
# read them, remove them") from the +create_simple_api_tool+ PARAMETER to the
# public BUILDER METHOD. The same three sources condemn both:
#
# * +porting-sdk/schema.json+ +$defs/Webhook+ declares exactly ten properties
#   under +unevaluatedProperties: {"not": {}}+ — +body+ is not among them, so
#   emitting it is a SCHEMA VIOLATION.
# * +mod_openai/actions.c:735-739+ and +bedrock.c:4920-4926+ read url, method,
#   form_param, +params+ and +headers+ and nothing else; +grep -n '"body"'+
#   across both returns ZERO matches.
# * So the method's only possible effect was producing an invalid document while
#   silently discarding the caller's payload.
#
# +params+ is the correct method for POST/PUT request data — it writes the
# +params+ key, which IS in the contract and IS read.
class DataMapBodyBuilderRemovedTest < Minitest::Test
  include DataMapTestAliases

  def test_body_method_is_gone
    refute_respond_to DM.new('t'), :body,
                      'DataMap#body must be removed — it writes a schema-forbidden key ' \
                      'that no engine reader consumes; use params instead'
  end

  # The replacement must keep working — this is the positive control.
  def test_params_still_writes_the_contract_key
    wh = DM.new('t')
           .webhook('POST', 'https://x.test')
           .params({ 'q' => '${query}' })
           .to_swaig_function['data_map']['webhooks'].first

    assert_equal({ 'q' => '${query}' }, wh['params'])
    refute wh.key?('body')
  end
end
