# frozen_string_literal: true

# Example: Basic agent with tools, hints, and language configuration.
#
# This is the simplest possible agent -- it defines a prompt, registers
# a couple of tools, adds speech recognition hints, and serves over HTTP.

require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'weather_agent', route: '/')

# --- Prompt (using POM sections) ---

agent.prompt_add_section(
  'Role',
  'You are a friendly weather assistant. Help callers check the weather ' \
  'in any city. Be concise and cheerful.'
)

agent.prompt_add_section(
  'Guidelines',
  nil,
  bullets: [
    'Always confirm the city before looking up weather.',
    'Provide temperature in both Fahrenheit and Celsius.',
    'If the user seems done, wish them a great day and hang up.'
  ]
)

# --- Tools ---

agent.define_tool(
  name:        'get_weather',
  description: 'Get the current weather for a city',
  parameters:  {
    'city' => { 'type' => 'string', 'description' => 'The city to look up' }
  }
) do |args, _raw_data|
  city = args['city'] || 'unknown'
  # In production, call a real weather API here
  SignalWire::Swaig::FunctionResult.new(
    "The weather in #{city} is 72F (22C), partly cloudy with a light breeze."
  )
end

agent.define_tool(
  name:        'get_forecast',
  description: 'Get a 3-day forecast for a city',
  parameters:  {
    'city' => { 'type' => 'string', 'description' => 'The city to look up' }
  }
) do |args, _raw_data|
  city = args['city'] || 'unknown'
  SignalWire::Swaig::FunctionResult.new(
    "3-day forecast for #{city}: Today 72F partly cloudy, " \
    'Tomorrow 68F rain likely, Day after 75F sunny.'
  )
end

# --- Hints & Language ---

agent.add_hints(%w[weather forecast temperature Fahrenheit Celsius])

agent.add_language('English', 'en-US', 'elevenlabs.rachel')

# --- LLM parameters ---

agent.set_prompt_llm_params(temperature: 0.3, top_p: 0.9)

# --- Run ---

puts "Starting weather agent on port #{agent.port}..."
agent.run
