# frozen_string_literal: true

# Example: Wikipedia search skill.
#
# Demonstrates the wikipedia_search skill for factual information
# retrieval with custom configuration.

require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'Wikipedia Assistant', route: '/wiki-demo')

agent.add_language('name' => 'English', 'code' => 'en-US', 'voice' => 'elevenlabs.rachel')

# Add datetime skill for basic date/time queries
begin
  agent.add_skill('datetime')
  puts 'Added datetime skill'
rescue => e
  puts "Failed to add datetime skill: #{e.message}"
end

# Add wikipedia search skill
begin
  agent.add_skill('wikipedia_search', {
    'num_results'       => 2,
    'no_results_message' => "I couldn't find any Wikipedia articles about '{query}'. " \
                            'Try different keywords or a related topic.'
  })
  puts 'Added Wikipedia search skill'
rescue => e
  puts "Failed to add Wikipedia skill: #{e.message}"
  exit 1
end

puts "Loaded skills: #{agent.list_skills.join(', ')}"
puts
puts 'Example queries:'
puts '  "Tell me about Albert Einstein"'
puts '  "What is quantum physics?"'
puts '  "Who was Marie Curie?"'
puts
puts "Starting Wikipedia Assistant on port #{agent.port}..."
agent.run
