# frozen_string_literal: true

# Example: Deploy a voice application end-to-end with SWML and call flows.
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

# 1. Create a SWML script
puts 'Creating SWML script...'
swml = client.fabric.swml_scripts.create(
  name:     'Greeting Script',
  contents: { 'sections' => { 'main' => [{ 'play' => { 'url' => 'say:Hello from SignalWire' } }] } }
)
swml_id = swml['id']
puts "  Created SWML script: #{swml_id}"

# 2. List SWML scripts to confirm. The fabric list endpoints return their rows
#    under a "data" envelope; normalize whether the body is that envelope Hash or
#    an Array wrapping it.
def list_rows(resp)
  return resp.flat_map { |e| list_rows(e) } if resp.is_a?(Array)

  resp.is_a?(Hash) ? (resp['data'] || []) : []
end

puts "\nListing SWML scripts..."
scripts = client.fabric.swml_scripts.list
list_rows(scripts).each do |s|
  puts "  - #{s['id']}: #{s.fetch('display_name', 'unnamed')}"
end

# 3. Create a call flow
puts "\nCreating call flow..."
flow = client.fabric.call_flows.create(title: 'Main IVR Flow')
flow_id = flow['id']
puts "  Created call flow: #{flow_id}"

# 4. Deploy a version of the call flow
puts "\nDeploying call flow version..."
safe('Deploy version') { client.fabric.call_flows.deploy_version(flow_id, { document_version: 1 }) }

# 5. List call flow versions
puts "\nListing call flow versions..."
safe('List versions') do
  versions = client.fabric.call_flows.list_versions(flow_id)
  list_rows(versions).each do |v|
    puts "  - Version: #{v.fetch('label', v.fetch('id', 'unknown'))}"
  end
end

# 6. List addresses for the call flow
puts "\nListing call flow addresses..."
safe('List addresses') do
  addrs = client.fabric.call_flows.list_addresses(flow_id)
  list_rows(addrs).each do |a|
    puts "  - #{a.fetch('display_name', a.fetch('id', 'unknown'))}"
  end
end

# 7. Create a SWML webhook as an alternative approach
puts "\nCreating SWML webhook..."
webhook = client.fabric.swml_webhooks.create(
  name:                'External Handler',
  primary_request_url: 'https://example.com/swml-handler'
)
webhook_id = webhook['id']
puts "  Created webhook: #{webhook_id}"

# 8. Clean up
puts "\nCleaning up..."
client.fabric.swml_webhooks.delete(webhook_id)
puts "  Deleted webhook #{webhook_id}"
client.fabric.call_flows.delete(flow_id)
puts "  Deleted call flow #{flow_id}"
client.fabric.swml_scripts.delete(swml_id)
puts "  Deleted SWML script #{swml_id}"
