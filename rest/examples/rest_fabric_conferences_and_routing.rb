# frozen_string_literal: true

# Example: Conference infrastructure, cXML resources, generic routing, and tokens.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'

client = SignalWire::REST::RestClient.new

def safe(label)
  result = yield
  puts "  #{label}: OK"
  result
rescue SignalWire::REST::SignalWireRestError => e
  puts "  #{label}: failed (#{e.status_code})"
  nil
end

# 1. Create a conference room
puts 'Creating conference room...'
room = client.fabric.conference_rooms.create(name: 'team-standup')
room_id = room['id']
puts "  Created conference room: #{room_id}"

# 2. List conference room addresses
puts "\nListing conference room addresses..."
begin
  addrs = client.fabric.conference_rooms.list_addresses(room_id)
  (addrs['data'] || []).each do |a|
    puts "  - #{a.fetch('display_name', a.fetch('id', 'unknown'))}"
  end
rescue SignalWire::REST::SignalWireRestError => e
  puts "  List addresses failed: #{e.status_code}"
end

# 3. Create a cXML script
puts "\nCreating cXML script..."
cxml = client.fabric.cxml_scripts.create(
  name:     'Hold Music Script',
  contents: '<Response><Say>Please hold.</Say><Play>https://example.com/hold.mp3</Play></Response>'
)
cxml_id = cxml['id']
puts "  Created cXML script: #{cxml_id}"

# 4. Create a cXML webhook
puts "\nCreating cXML webhook..."
cxml_wh = client.fabric.cxml_webhooks.create(
  name:                'External cXML Handler',
  primary_request_url: 'https://example.com/cxml-handler'
)
cxml_wh_id = cxml_wh['id']
puts "  Created cXML webhook: #{cxml_wh_id}"

# 5. Create a relay application
puts "\nCreating relay application..."
relay_app = client.fabric.relay_applications.create(name: 'Inbound Handler', topic: 'office')
relay_id = relay_app['id']
puts "  Created relay application: #{relay_id}"

# 6. Generic resources: list all
puts "\nListing all fabric resources..."
resources = client.fabric.resources.list
(resources['data'] || []).first(5).each do |r|
  puts "  - #{r.fetch('type', 'unknown')}: #{r.fetch('display_name', r.fetch('id', 'unknown'))}"
end

# 7. Get a specific generic resource
first = (resources['data'] || [{}]).first
if first && first['id']
  detail = client.fabric.resources.get(first['id'])
  puts "  Resource detail: #{detail.fetch('display_name', 'N/A')} (#{detail.fetch('type', 'N/A')})"
end

# 8. Assign a phone route to a resource (demo)
puts "\nAssigning phone route (demo)..."
safe('Phone route') { client.fabric.resources.assign_phone_route(relay_id, phone_number: '+15551234567') }

# 9. Assign a domain application (demo)
puts "\nAssigning domain application (demo)..."
safe('Domain app') { client.fabric.resources.assign_domain_application(relay_id, domain: 'app.example.com') }

# 10. Generate tokens
puts "\nGenerating tokens..."
safe('Guest token') do
  guest = client.fabric.tokens.create_guest_token(resource_id: relay_id)
  puts "  Guest token: #{guest.fetch('token', '')[0, 40]}..."
end
safe('Invite token') do
  invite = client.fabric.tokens.create_invite_token(resource_id: relay_id)
  puts "  Invite token: #{invite.fetch('token', '')[0, 40]}..."
end
safe('Embed token') do
  embed = client.fabric.tokens.create_embed_token(resource_id: relay_id)
  puts "  Embed token: #{embed.fetch('token', '')[0, 40]}..."
end

# 11. Clean up
puts "\nCleaning up..."
client.fabric.relay_applications.delete(relay_id)
puts "  Deleted relay application #{relay_id}"
client.fabric.cxml_webhooks.delete(cxml_wh_id)
puts "  Deleted cXML webhook #{cxml_wh_id}"
client.fabric.cxml_scripts.delete(cxml_id)
puts "  Deleted cXML script #{cxml_id}"
client.fabric.conference_rooms.delete(room_id)
puts "  Deleted conference room #{room_id}"
