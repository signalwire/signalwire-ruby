# frozen_string_literal: true

# Example: Server-side DataMap tools that execute on SignalWire servers.
#
# DataMap tools don't require webhook endpoints -- they define API calls
# and response templates that run entirely on SignalWire infrastructure.

require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'datamap_agent', route: '/')

agent.prompt_add_section(
  'Role',
  'You are a helpful assistant that can look up weather, convert currencies, ' \
  'and tell jokes. Use the available tools to answer user questions.'
)

# --- DataMap Tool 1: Weather API ---

weather = SignalWire::DataMap.new('get_weather')
                             .purpose('Get the current weather for a location')
                             .parameter('city', 'string', 'City name', required: true)
                             .parameter('units', 'string', 'Temperature units: metric or imperial', required: false)
                             .webhook('GET', 'https://api.weatherapi.com/v1/current.json?key=${global_data.weather_api_key}&q=${args.city}')
                             .output(
                               SignalWire::Swaig::FunctionResult.new(
                                 'Current weather in ${args.city}: ${response.current.temp_f}F ' \
                                 '(${response.current.temp_c}C), ${response.current.condition.text}. ' \
                                 'Wind: ${response.current.wind_mph} mph.'
                               )
                             )

agent.register_swaig_function(weather.to_swaig_function)

# --- DataMap Tool 2: Expression-based calculator ---

calculator = SignalWire::DataMap.new('simple_math')
                                .purpose('Evaluate a simple math expression')
                                .parameter('expression', 'string', 'A math expression like "add", "subtract"', required: true)
                                .parameter('a', 'number', 'First number', required: true)
                                .parameter('b', 'number', 'Second number', required: true)

calculator.expression(
  '${args.expression}',
  'add',
  SignalWire::Swaig::FunctionResult.new('The sum is: the result of ${args.a} + ${args.b}'),
  nomatch_output: SignalWire::Swaig::FunctionResult.new('Unknown operation: ${args.expression}')
)

calculator.expression(
  '${args.expression}',
  'subtract',
  SignalWire::Swaig::FunctionResult.new('The difference is: the result of ${args.a} - ${args.b}')
)

agent.register_swaig_function(calculator.to_swaig_function)

# --- DataMap Tool 3: Simple API tool (class method shortcut) ---

joke = SignalWire::DataMap.create_simple_api_tool(
  name: 'get_joke',
  url: 'https://official-joke-api.appspot.com/random_joke',
  response_template: 'Here is a joke: ${response.setup} ... ${response.punchline}',
  method: 'GET'
)

agent.register_swaig_function(joke.to_swaig_function)

# --- Global data (API keys would go here) ---

agent.set_global_data(
  'weather_api_key' => ENV.fetch('WEATHER_API_KEY', 'demo-key')
)

# --- Hints ---

agent.add_hints(%w[weather temperature forecast joke math calculate])

puts "Starting DataMap agent on port #{agent.port}..."
agent.run
