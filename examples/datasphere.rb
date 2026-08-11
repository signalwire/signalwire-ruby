# frozen_string_literal: true

# Example: DataSphere skill with multiple instances.
#
# Demonstrates loading the datasphere skill multiple times with
# different configurations and custom tool names for separate
# knowledge bases (drinks, food, general).
#
# Replace the example credentials with your actual DataSphere details.

require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'Multi-DataSphere', route: '/datasphere-demo')

agent.add_language('English', 'en-US', 'elevenlabs.rachel')

# Add utility skills
begin
  agent.add_skill('datetime')
  agent.add_skill('math')
  puts 'Added datetime and math skills'
rescue StandardError => e
  puts "Skill load warning: #{e.message}"
end

# Example credentials -- replace with your actual DataSphere details
example_config = {
  'space_name' => 'your-space',
  'project_id' => 'your-project-id',
  'token' => 'your-token'
}

# Instance 1: Drinks knowledge
begin
  drinks = example_config.merge(
    'document_id' => 'drinks-doc-123',
    'tool_name' => 'search_drinks_knowledge',
    'tags' => %w[Drinks Bar Cocktails],
    'count' => 2,
    'distance' => 5.0,
    'no_results_message' => "I couldn't find drink info about '{query}'. Try a different cocktail."
  )
  agent.add_skill('datasphere', drinks)
  puts 'Added drinks knowledge (tool: search_drinks_knowledge)'
rescue StandardError => e
  puts "Drinks DataSphere: #{e.message}"
end

# Instance 2: Food knowledge
begin
  food = example_config.merge(
    'document_id' => 'food-doc-456',
    'tool_name' => 'search_food_knowledge',
    'tags' => %w[Food Recipes Cooking],
    'count' => 3,
    'distance' => 4.0,
    'no_results_message' => "I couldn't find recipes about '{query}'. Try a different dish."
  )
  agent.add_skill('datasphere', food)
  puts 'Added food knowledge (tool: search_food_knowledge)'
rescue StandardError => e
  puts "Food DataSphere: #{e.message}"
end

# Instance 3: General knowledge (default tool name)
begin
  agent.add_skill('datasphere', example_config.merge(
                                  'document_id' => 'general-doc-789',
                                  'count' => 1,
                                  'distance' => 3.0
                                ))
  puts 'Added general knowledge (tool: search_knowledge)'
rescue StandardError => e
  puts "General DataSphere: #{e.message}"
end

puts "\nLoaded skills: #{agent.list_skills.join(', ')}"
puts "Starting DataSphere agent on port #{agent.port}..."
agent.run
