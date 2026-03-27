# frozen_string_literal: true

# Example: Create an AI agent, assign a phone number, and place a test call.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'

client = SignalWire::REST::RestClient.new

# 1. Create an AI agent
puts 'Creating AI agent...'
agent = client.fabric.ai_agents.create(
  name:   'Demo Support Bot',
  prompt: { 'text' => 'You are a friendly support agent for Acme Corp.' }
)
agent_id = agent['id']
puts "  Created agent: #{agent_id}"

# 2. List all AI agents
puts "\nListing AI agents..."
agents = client.fabric.ai_agents.list
(agents['data'] || []).each do |a|
  puts "  - #{a['id']}: #{a.fetch('name', 'unnamed')}"
end

# 3. Search for a phone number
puts "\nSearching for available phone numbers..."
available = client.phone_numbers.search(area_code: '512', max_results: 3)
(available['data'] || []).each do |num|
  puts "  - #{num.fetch('e164', num.fetch('number', 'unknown'))}"
end

# 4. Place a test call (requires valid numbers)
puts "\nPlacing a test call..."
begin
  result = client.calling.dial(
    from_: '+15559876543',
    to:    '+15551234567',
    url:   'https://example.com/call-handler'
  )
  puts "  Call initiated: #{result}"
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Call failed (expected in demo): #{e.status_code}"
end

# 5. Clean up: delete the agent
puts "\nDeleting agent #{agent_id}..."
client.fabric.ai_agents.delete(agent_id)
puts '  Deleted.'
