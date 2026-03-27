# frozen_string_literal: true

# Example: Joke skill integration.
#
# Demonstrates adding the built-in joke skill to an agent.
# Requires API_NINJAS_KEY environment variable.

require 'signalwire'

api_key = ENV['API_NINJAS_KEY']
unless api_key
  puts 'Error: API_NINJAS_KEY environment variable is required.'
  puts 'Get your free API key from https://api.api-ninjas.com/'
  puts 'Then run: API_NINJAS_KEY=your_key ruby examples/joke_agent.rb'
  exit 1
end

agent = SignalWire::AgentBase.new(
  name:  'Joke Skill Demo',
  route: '/joke-skill'
)

agent.prompt_add_section(
  'Personality',
  'You are a cheerful comedian who loves sharing jokes and making people laugh.'
)

agent.prompt_add_section('Instructions', nil, bullets: [
  'When users ask for jokes, use your joke functions to provide them.',
  'Be enthusiastic and fun in your responses.',
  'You can tell both regular jokes and dad jokes.'
])

# Add the built-in joke skill
agent.add_skill('joke', 'api_key' => api_key)

agent.add_hints(%w[joke funny laugh comedy])

puts "Loaded skills: #{agent.list_skills.join(', ')}"
puts "Starting joke agent on port #{agent.port}..."
agent.run
