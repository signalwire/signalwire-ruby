# frozen_string_literal: true

# Example: Joke skill via the modular skills system.
#
# Demonstrates the joke skill with DataMap for serverless execution.
# Compare with joke_agent.rb (raw data_map).
#
# Required: API_NINJAS_KEY environment variable.

require 'signalwire'

api_key = ENV['API_NINJAS_KEY']
abort("Error: API_NINJAS_KEY environment variable is required.\n" \
      "Get your free API key from https://api.api-ninjas.com/") unless api_key

agent = SignalWire::AgentBase.new(name: 'joke-skill-demo', route: '/joke-skill')

agent.add_language('English', 'en-US', 'elevenlabs.rachel')

agent.prompt_add_section(
  'Personality',
  'You are a cheerful comedian who loves sharing jokes and making people laugh.'
)

agent.prompt_add_section('Instructions', nil, bullets: [
  'When users ask for jokes, use your joke functions to provide them',
  'Be enthusiastic and fun in your responses',
  'You can tell both regular jokes and dad jokes'
])

agent.add_skill('joke', 'api_key' => api_key)

puts 'Joke Skill Demo (modular skills system)'
puts '  Benefits over raw DataMap:'
puts '    - One-liner integration via skills system'
puts '    - Automatic validation and error handling'
puts '    - Reusable across agents'
puts "Starting agent on port #{agent.port}..."
agent.run
