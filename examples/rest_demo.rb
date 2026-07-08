# frozen_string_literal: true

# Example: REST client usage -- manage resources via HTTP API.
#
# The REST client provides synchronous access to all SignalWire APIs:
# Fabric, Calling, Video, Datasphere, Phone Numbers, and more.
#
# Set these env vars:
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space

require 'signalwire'
require 'signalwire/rest/rest_client'  # opt-in subsystem (Python: from signalwire.rest import Client)

client = SignalWire::REST::RestClient.new

# 1. Create an AI agent via Fabric API
puts 'Creating AI agent...'
begin
  agent = client.fabric.ai_agents.create(
    name:   'Ruby Demo Bot',
    prompt: { 'text' => 'You are a helpful assistant powered by Ruby.' }
  )
  agent_id = agent['id']
  puts "  Created agent: #{agent_id}"
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Failed: #{e.status_code} -- #{e.message}"
  agent_id = nil
end

# 2. List AI agents
puts "\nListing AI agents..."
begin
  agents = client.fabric.ai_agents.list
  (agents['data'] || []).each do |a|
    puts "  - #{a['id']}: #{a.fetch('name', 'unnamed')}"
  end
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Failed: #{e.status_code}"
end

# 3. Search for phone numbers
puts "\nSearching phone numbers..."
begin
  available = client.phone_numbers.search(area_code: '512', max_results: 3)
  (available['data'] || []).each do |num|
    puts "  - #{num.fetch('e164', num.fetch('number', 'unknown'))}"
  end
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Failed: #{e.status_code}"
end

# 4. Create a video room
puts "\nCreating video room..."
begin
  room = client.video.rooms.create(name: 'ruby-demo-room', max_members: 5)
  room_id = room['id']
  puts "  Created room: #{room_id}"
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Failed: #{e.status_code}"
  room_id = nil
end

# 5. List queues
puts "\nListing queues..."
begin
  queues = client.queues.list
  (queues['data'] || []).each do |q|
    puts "  - #{q['id']}: #{q.fetch('name', q.fetch('friendly_name', 'unnamed'))}"
  end
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Failed: #{e.status_code}"
end

# 6. Clean up
puts "\nCleaning up..."
if agent_id
  client.fabric.ai_agents.delete(agent_id)
  puts "  Deleted agent #{agent_id}"
end
if room_id
  client.video.rooms.delete(room_id)
  puts "  Deleted room #{room_id}"
end

puts "\nDone."
