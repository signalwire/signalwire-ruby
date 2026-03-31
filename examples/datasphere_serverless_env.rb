# frozen_string_literal: true

# Example: DataSphere serverless skill from environment variables.
#
# Required: SIGNALWIRE_SPACE_NAME, SIGNALWIRE_PROJECT_ID, SIGNALWIRE_TOKEN,
#           DATASPHERE_DOCUMENT_ID
# Optional: DATASPHERE_COUNT, DATASPHERE_DISTANCE, DATASPHERE_TAGS

require 'signalwire'

def require_env(name)
  value = ENV[name]
  abort("Error: Required environment variable #{name} is not set.") unless value && !value.empty?
  value
end

document_id = require_env('DATASPHERE_DOCUMENT_ID')
count       = (ENV['DATASPHERE_COUNT'] || '3').to_i
distance    = (ENV['DATASPHERE_DISTANCE'] || '4.0').to_f

agent = SignalWire::AgentBase.new(name: 'datasphere-serverless-env', route: '/datasphere-env')

agent.add_language('name' => 'English', 'code' => 'en-US', 'voice' => 'elevenlabs.rachel')

agent.prompt_add_section(
  'Role',
  'You are a knowledge assistant with access to a document library. ' \
  'Search the knowledge base to answer user questions.'
)

begin
  agent.add_skill('datetime')
  agent.add_skill('math')
rescue => e
  puts "Skill warning: #{e.message}"
end

config = {
  'document_id' => document_id,
  'count'       => count,
  'distance'    => distance
}

tags_str = ENV['DATASPHERE_TAGS']
config['tags'] = tags_str.split(',').map(&:strip) if tags_str && !tags_str.empty?

begin
  agent.add_skill('datasphere', config)
  puts 'Added DataSphere serverless skill'
rescue => e
  puts "DataSphere error: #{e.message}"
end

puts "DataSphere Serverless Environment Demo"
puts "  Document: #{document_id}"
puts "  Count: #{count}, Distance: #{distance}"
puts "Starting agent on port #{agent.port}..."
agent.run
