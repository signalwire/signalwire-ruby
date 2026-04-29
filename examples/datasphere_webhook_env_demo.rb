# frozen_string_literal: true

# Example: Webhook-based DataSphere skill from environment variables.
#
# Compare with datasphere_serverless_env.rb for the serverless approach.
# Required: DATASPHERE_DOCUMENT_ID

require 'signalwire'

def require_env(name)
  value = ENV[name]
  abort("Error: Required environment variable #{name} is not set.") unless value && !value.empty?
  value
end

document_id = require_env('DATASPHERE_DOCUMENT_ID')
count       = (ENV['DATASPHERE_COUNT'] || '3').to_i
distance    = (ENV['DATASPHERE_DISTANCE'] || '4.0').to_f

agent = SignalWire::AgentBase.new(name: 'datasphere-webhook-env', route: '/datasphere-webhook')

agent.add_language('name' => 'English', 'code' => 'en-US', 'voice' => 'elevenlabs.rachel')

agent.prompt_add_section(
  'Role',
  'You are a knowledge assistant using webhook-based DataSphere for retrieval.'
)

begin
  agent.add_skill('datetime')
  agent.add_skill('math')
rescue => e
  puts "Skill warning: #{e.message}"
end

begin
  agent.add_skill('datasphere',
    'document_id' => document_id,
    'count'       => count,
    'distance'    => distance,
    'mode'        => 'webhook')
  puts 'Added DataSphere webhook skill'
rescue => e
  puts "DataSphere error: #{e.message}"
end

puts 'DataSphere Webhook Environment Demo'
puts "  Document: #{document_id}"
puts '  Execution: Webhook-based (traditional)'
puts ''
puts '  Webhook:    Full control, custom error handling'
puts '  Serverless: No webhooks, lower latency, executes on SignalWire'
puts "Starting agent on port #{agent.port}..."
agent.run
