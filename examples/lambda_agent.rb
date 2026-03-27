# frozen_string_literal: true

# Example: Serverless-style agent pattern.
#
# Shows how to create an agent whose Rack app can be exported for use
# in serverless environments (AWS Lambda via lamby, Cloud Functions,
# or any Rack-compatible host).
#
# For local testing, simply run this file directly.

require 'signalwire'

agent = SignalWire::AgentBase.new(
  name:  'lambda-agent',
  route: '/'
)

agent.add_language('name' => 'English', 'code' => 'en-US', 'voice' => 'elevenlabs.rachel')

agent.prompt_add_section(
  'Role',
  'You are a helpful AI assistant running in a serverless environment.'
)

agent.prompt_add_section('Instructions', nil, bullets: [
  'Greet users warmly and offer help.',
  'Use the greet_user function when asked to greet someone.',
  'Use the get_time function when asked about the current time.'
])

agent.define_tool(
  name:        'greet_user',
  description: 'Greet a user by name',
  parameters:  {
    'name' => { 'type' => 'string', 'description' => 'Name to greet' }
  }
) do |args, _raw_data|
  name = args['name'] || 'friend'
  SignalWire::Swaig::FunctionResult.new("Hello #{name}! I'm running in serverless mode!")
end

agent.define_tool(
  name:        'get_time',
  description: 'Get the current time',
  parameters:  {}
) do |_args, _raw_data|
  SignalWire::Swaig::FunctionResult.new("Current time: #{Time.now.iso8601}")
end

# In a real serverless deployment you would export the Rack app:
#   APP = agent.rack_app
# and point your handler at APP.
#
# For local testing:
if __FILE__ == $PROGRAM_NAME
  puts "Starting lambda-style agent on port #{agent.port}..."
  agent.run
end
