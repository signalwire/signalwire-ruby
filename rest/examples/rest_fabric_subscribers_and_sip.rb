# frozen_string_literal: true

# Example: Provision a SIP-enabled user on Fabric.
#
# Set these env vars (or pass them directly to RestClient.new):
#   SIGNALWIRE_PROJECT_ID   - your SignalWire project ID
#   SIGNALWIRE_API_TOKEN    - your SignalWire API token
#   SIGNALWIRE_SPACE        - your SignalWire space (e.g. example.signalwire.com)

require 'signalwire'
require 'signalwire/rest/rest_client'  # opt-in subsystem (Python: from signalwire.rest import Client)

client = SignalWire::REST::RestClient.new

def safe(label)
  result = yield
  puts "  #{label}: OK"
  result
rescue SignalWire::REST::SignalWireRestError => e
  puts "  #{label}: failed (#{e.status_code})"
  nil
end

# 1. Create a subscriber
puts 'Creating subscriber...'
subscriber = client.fabric.subscribers.create(
  email:        'alice@example.com',
  first_name:   'Alice',
  last_name:    'Johnson',
  display_name: 'Alice Johnson'
)
sub_id = subscriber['id']
inner_sub_id = subscriber.dig('subscriber', 'id') || sub_id
puts "  Created subscriber: #{sub_id}"

# 2. Add a SIP endpoint to the subscriber
puts "\nCreating SIP endpoint on subscriber..."
endpoint = client.fabric.subscribers.create_sip_endpoint(
  sub_id,
  username: 'alice_sip',
  password: 'SecurePass123!'
)
ep_id = endpoint['id']
puts "  Created SIP endpoint: #{ep_id}"

# 3. List SIP endpoints on the subscriber
puts "\nListing subscriber SIP endpoints..."
endpoints = client.fabric.subscribers.list_sip_endpoints(sub_id)
(endpoints['data'] || []).each do |ep|
  puts "  - #{ep['id']}: #{ep.fetch('username', 'unknown')}"
end

# 4. Get specific SIP endpoint details
puts "\nGetting SIP endpoint #{ep_id}..."
ep_detail = client.fabric.subscribers.get_sip_endpoint(sub_id, ep_id)
puts "  Username: #{ep_detail.fetch('username', 'N/A')}"

# 5. Create a standalone SIP gateway
puts "\nCreating SIP gateway..."
gateway = client.fabric.sip_gateways.create(
  name:       'Office PBX Gateway',
  uri:        'sip:pbx.example.com',
  encryption: 'required',
  ciphers:    ['AES_256_CM_HMAC_SHA1_80'],
  codecs:     %w[PCMU PCMA]
)
gw_id = gateway['id']
puts "  Created SIP gateway: #{gw_id}"

# 6. List fabric addresses
puts "\nListing fabric addresses..."
begin
  addresses = client.fabric.addresses.list
  (addresses['data'] || []).first(5).each do |addr|
    puts "  - #{addr.fetch('display_name', addr.fetch('id', 'unknown'))}"
  end

  # 7. Get a specific fabric address
  first_addr = (addresses['data'] || [{}]).first
  if first_addr && first_addr['id']
    addr_detail = client.fabric.addresses.get(first_addr['id'])
    puts "  Address detail: #{addr_detail.fetch('display_name', 'N/A')}"
  end
rescue SignalWire::REST::SignalWireRestError => e
  puts "  Fabric addresses failed: #{e.status_code}"
end

# 8. Generate a subscriber token
puts "\nGenerating subscriber token..."
safe('Subscriber token') do
  token = client.fabric.tokens.create_subscriber_token(reference: inner_sub_id)
  puts "  Token: #{token.fetch('token', '')[0, 40]}..."
end

# 9. Clean up
puts "\nCleaning up..."
client.fabric.subscribers.delete_sip_endpoint(sub_id, ep_id)
puts "  Deleted SIP endpoint #{ep_id}"
client.fabric.subscribers.delete(sub_id)
puts "  Deleted subscriber #{sub_id}"
client.fabric.sip_gateways.delete(gw_id)
puts "  Deleted SIP gateway #{gw_id}"
