# frozen_string_literal: true

# Example: Multiple SWML routes on one AgentServer.
#
# Demonstrates hosting a voice AI agent alongside other agents on
# different routes using AgentServer's longest-prefix-match routing.
#
# Endpoints:
#   /voice   -- Voice AI agent
#   /info    -- Information desk agent
#   /health  -- Built-in health check

require 'signalwire'

# --- Voice AI agent ---

voice = SignalWire::AgentBase.new(name: 'voice-assistant', route: '/voice')
voice.prompt_add_section('Role', 'You are a helpful voice assistant.')
voice.prompt_add_section('Instructions', nil, bullets: [
  'Greet callers warmly.',
  'Be concise in your responses.',
  'Use the get_time function when asked about the current time.'
])
voice.add_language('English', 'en-US', 'elevenlabs.rachel')

voice.define_tool(
  name: 'get_time', description: 'Get the current time', parameters: {}, handler: nil
) do |_args, _raw_data|
  now = Time.now.strftime('%I:%M %p')
  SignalWire::Swaig::FunctionResult.new("The current time is #{now}")
end

# --- Information desk agent ---

info = SignalWire::AgentBase.new(name: 'info-desk', route: '/info')
info.prompt_add_section('Role', 'You are an information desk assistant.')
info.prompt_add_section('Guidelines', nil, bullets: [
  'Provide accurate information about the building and services.',
  'Direct callers to the correct department.',
  'Be polite and professional.'
])

info.define_tool(
  name: 'get_directory', description: 'Look up a department',
  parameters: { 'department' => { 'type' => 'string', 'description' => 'Department name' } }, handler: nil
) do |args, _raw_data|
  dept = args['department'] || 'unknown'
  SignalWire::Swaig::FunctionResult.new("#{dept.capitalize}: Floor 3, Room 302. Hours 9 AM-5 PM.")
end

# --- Server ---

server = SignalWire::AgentServer.new(host: '0.0.0.0', port: 8080)
server.register(voice)
server.register(info)

puts 'Starting multi-endpoint server on port 8080...'
puts '  /voice  -- Voice AI agent'
puts '  /info   -- Information desk agent'
puts '  /health -- Health check'
server.run
