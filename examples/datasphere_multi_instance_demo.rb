# frozen_string_literal: true

# Example: DataSphere skill with multiple instances and custom tool names.
#
# Loads the datasphere skill three times with different knowledge bases.
# Replace the example credentials with your actual DataSphere details.

require 'signalwire'

agent = SignalWire::AgentBase.new(name: 'multi-datasphere', route: '/datasphere-multi')

agent.add_language('English', 'en-US', 'elevenlabs.rachel')

agent.prompt_add_section(
  'Role',
  'You are an assistant with access to multiple knowledge bases. ' \
  'Use the appropriate search tool depending on the topic.'
)

begin
  agent.add_skill('datetime')
  agent.add_skill('math')
rescue => e
  puts "Skill warning: #{e.message}"
end

example_config = {
  'space_name' => 'your-space',
  'project_id' => 'your-project-id',
  'token'      => 'your-token'
}

# Instance 1: Drinks knowledge
begin
  agent.add_skill('datasphere', example_config.merge(
    'document_id' => 'drinks-doc-123',
    'tool_name'   => 'search_drinks_knowledge',
    'count'       => 2,
    'distance'    => 5.0
  ))
  puts 'Added drinks knowledge (tool: search_drinks_knowledge)'
rescue => e
  puts "Drinks DataSphere: #{e.message}"
end

# Instance 2: Food knowledge
begin
  agent.add_skill('datasphere', example_config.merge(
    'document_id' => 'food-doc-456',
    'tool_name'   => 'search_food_knowledge',
    'count'       => 3,
    'distance'    => 4.0
  ))
  puts 'Added food knowledge (tool: search_food_knowledge)'
rescue => e
  puts "Food DataSphere: #{e.message}"
end

# Instance 3: General knowledge (default tool name)
begin
  agent.add_skill('datasphere', example_config.merge(
    'document_id' => 'general-doc-789',
    'count'       => 1,
    'distance'    => 3.0
  ))
  puts 'Added general knowledge (tool: search_knowledge)'
rescue => e
  puts "General DataSphere: #{e.message}"
end

puts "\nTools: search_drinks_knowledge, search_food_knowledge, search_knowledge"
puts "Note: Replace credentials with your actual DataSphere details."
puts "Starting multi-datasphere agent on port #{agent.port}..."
agent.run
